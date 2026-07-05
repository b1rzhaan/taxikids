import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme.dart';
import '../../core/voice.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'navigation_screen.dart';

/// 2GIS navigator using MapGL JS inside a WebView (works with the standard
/// 2GIS Platform key — MapGL JS is included in the demo key).
///
/// Heading to the child → route is built from the driver's live GPS to the
/// pickup point. Carrying the child → the trip's pickup→dropoff route is used.
class DgisWebNavigationScreen extends StatefulWidget {
  final Trip trip;
  final double targetLat;
  final double targetLng;
  final String targetText;
  final bool headingToPickup;

  const DgisWebNavigationScreen({
    super.key,
    required this.trip,
    required this.targetLat,
    required this.targetLng,
    required this.targetText,
    required this.headingToPickup,
  });

  @override
  State<DgisWebNavigationScreen> createState() =>
      _DgisWebNavigationScreenState();
}

class _DgisWebNavigationScreenState extends State<DgisWebNavigationScreen> {
  WebViewController? _controller;
  List<List<double>> _route = const [];
  String _carIcon = '';
  bool _ready = false;
  bool _arrived = false;
  bool _noKey = false;
  double _remainingKm = 0;
  int _etaMin = 0;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final key = await MapsService.mapKey();
    if (key.isEmpty) {
      setState(() => _noKey = true);
      return;
    }
    _route = await _resolveRoute();
    try {
      final bytes = await rootBundle.load('assets/car.png');
      _carIcon = 'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
    } catch (_) {}
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg)
      ..addJavaScriptChannel('KT', onMessageReceived: _onJsMessage)
      ..loadHtmlString(_html(key));
    setState(() => _controller = controller);
  }

  /// Always build a FRESH 2GIS route so it follows real roads (the trip's
  /// stored polyline may be a 2-point stub from an older provider).
  /// Heading to child → from driver GPS to pickup; carrying → pickup to dropoff.
  Future<List<List<double>>> _resolveRoute() async {
    double? oLat, oLng;
    if (widget.headingToPickup) {
      final gps = await _currentGps();
      if (gps != null) {
        oLat = gps.$1;
        oLng = gps.$2;
      }
    } else {
      oLat = widget.trip.pickupLat;
      oLng = widget.trip.pickupLng;
    }

    if (oLat != null && oLng != null) {
      try {
        final r = await MapsService.routePolyline(
          oLat: oLat,
          oLng: oLng,
          dLat: widget.targetLat,
          dLng: widget.targetLng,
        );
        if (r.length >= 2) return r;
      } catch (_) {}
    }
    // Fallbacks.
    if (widget.trip.polyline.length >= 2) return widget.trip.polyline;
    if (oLat != null && oLng != null) {
      return [
        [oLat, oLng],
        [widget.targetLat, widget.targetLng],
      ];
    }
    return widget.trip.polyline;
  }

  Future<(double, double)?> _currentGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      return (p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  void _onJsMessage(JavaScriptMessage message) {
    try {
      final m = jsonDecode(message.message) as Map<String, dynamic>;
      switch (m['type']) {
        case 'ready':
          setState(() => _ready = true);
          break;
        case 'pos':
          _remainingKm = (m['remainingKm'] as num).toDouble();
          _etaMin = (m['etaMin'] as num).toInt();
          _progress = (m['progress'] as num).toDouble().clamp(0, 1);
          setState(() {});
          TripsService.sendLocation(widget.trip.id,
              (m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
          break;
        case 'voice':
          Speaker.say('${m['text']}');
          break;
        case 'done':
          setState(() {
            _arrived = true;
            _progress = 1;
          });
          break;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    Speaker.stop();
    super.dispose();
  }

  String get _routeJson {
    final pts = _route.map((p) => [p[1], p[0]]).toList(growable: false);
    return jsonEncode(pts);
  }

  double get _speed {
    final d = widget.trip.routeDistanceM;
    final t = widget.trip.routeDurationS;
    return (d > 0 && t > 0) ? d / t : 6.7; // ~24 km/h
  }

  String get _arrivalClock {
    final at = DateTime.now().add(Duration(minutes: _arrived ? 0 : _etaMin));
    return DateFormat('HH:mm').format(at);
  }

  @override
  Widget build(BuildContext context) {
    if (_noKey) return _fallbackNotice();
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _controller == null
                ? const ColoredBox(color: AppColors.bg)
                : WebViewWidget(controller: _controller!),
          ),
          if (!_ready)
            const Positioned.fill(
              child: ColoredBox(
                color: AppColors.bg,
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.brand)),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _topBanner(),
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _bottomBar()),
        ],
      ),
    );
  }

  Widget _topBanner() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _arrived ? AppColors.success : AppColors.ink,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12)],
      ),
      child: Row(
        children: [
          InkResponse(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Icon(_arrived ? Icons.check_circle : Icons.navigation,
              color: _arrived ? Colors.white : AppColors.brand, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _arrived
                  ? 'Вы на месте'
                  : (widget.headingToPickup ? 'Едем к ребёнку' : 'Везём ребёнка'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<bool>(
            valueListenable: VoiceSettings.enabled,
            builder: (_, on, _) => InkResponse(
              onTap: () => VoiceSettings.setEnabled(!on),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(on ? Icons.volume_up : Icons.volume_off,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 16)],
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place, color: Color(0xFFF97316), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(widget.targetText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Yandex-style summary: distance · ETA · arrival clock.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_remainingKm.toStringAsFixed(1)} км',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                Text(_arrived ? 'на месте' : '$_etaMin мин',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDark)),
                Text(_arrivalClock,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFEDEEF0),
                valueColor: const AlwaysStoppedAnimation(AppColors.brand),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Свернуть навигатор'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackNotice() {
    return Scaffold(
      appBar: AppBar(title: const Text('Навигатор')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🗺️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              const Text('Карта 2GIS недоступна',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Не удалось получить ключ карты. Откроем простой навигатор.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NavigationScreen(
                        trip: widget.trip, targetText: widget.targetText),
                  ),
                ),
                child: const Text('Открыть навигатор'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _html(String key) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <style>html,body,#map{margin:0;padding:0;width:100%;height:100%;background:#F7F8FA}</style>
  <script src="https://mapgl.2gis.com/api/js/v1"></script>
</head>
<body>
  <div id="map"></div>
  <script>
    var KEY = "$key";
    var ROUTE = $_routeJson;               // [[lng,lat],...]
    var DEST = [${widget.targetLng}, ${widget.targetLat}];
    var SPEED = $_speed;                    // m/s

    function post(o){ try { KT.postMessage(JSON.stringify(o)); } catch(e){} }
    function rad(d){ return d*Math.PI/180; }
    function hav(a,b){
      var R=6371000, dLat=rad(b[1]-a[1]), dLon=rad(b[0]-a[0]);
      var s=Math.sin(dLat/2)*Math.sin(dLat/2)+Math.cos(rad(a[1]))*Math.cos(rad(b[1]))*Math.sin(dLon/2)*Math.sin(dLon/2);
      return 2*R*Math.asin(Math.sqrt(s));
    }
    function bearing(a,b){
      var dLon=rad(b[0]-a[0]);
      var y=Math.sin(dLon)*Math.cos(rad(b[1]));
      var x=Math.cos(rad(a[1]))*Math.sin(rad(b[1]))-Math.sin(rad(a[1]))*Math.cos(rad(b[1]))*Math.cos(dLon);
      return (Math.atan2(y,x)*180/Math.PI+360)%360;
    }
    // Cumulative distance along the route.
    var CUM = [0];
    for (var k=0;k<ROUTE.length-1;k++){ CUM.push(CUM[k] + hav(ROUTE[k], ROUTE[k+1])); }
    var TOTAL = CUM[CUM.length-1] || 0;

    // Position + heading + current segment at a given distance along the route.
    function along(dist){
      if (ROUTE.length < 2) return { pt: DEST, hd: 0, seg: 0 };
      var lo=0, hi=ROUTE.length-1;
      while (lo < ROUTE.length-1 && CUM[lo+1] < dist) lo++;
      var seg = Math.min(lo, ROUTE.length-2);
      var segLen = CUM[seg+1]-CUM[seg];
      var t = segLen > 0 ? (dist-CUM[seg])/segLen : 0;
      var a=ROUTE[seg], b=ROUTE[seg+1];
      return {
        pt: [a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t],
        hd: bearing(a,b),
        seg: seg
      };
    }

    // Precompute turns (significant heading changes) for voice guidance.
    var TURNS = [];
    for (var j=1;j<ROUTE.length-1;j++){
      var b1=bearing(ROUTE[j-1],ROUTE[j]);
      var b2=bearing(ROUTE[j],ROUTE[j+1]);
      var diff=((b2-b1+540)%360)-180;
      if (Math.abs(diff)>28) TURNS.push({ dist: CUM[j], dir: diff>0?'направо':'налево', done:false });
    }

    function hideClutter(map){
      var attempts = [ {ids:['poi']}, {types:['poi']}, {types:['label']}, {types:['poi','label']}, ['poi','label'] ];
      for (var a=0;a<attempts.length;a++){ try { if (map.hideLayers) map.hideLayers(attempts[a]); } catch(e){} }
    }

    // Car marker image (rear-view taxi PNG); the map is course-up so it always faces forward.
    var CAR_ICON = "$_carIcon";
    if (!CAR_ICON) {
      var svg='<svg xmlns="http://www.w3.org/2000/svg" width="44" height="44" viewBox="0 0 44 44">'
        +'<rect x="14" y="6" width="16" height="32" rx="7" fill="#FFCE00" stroke="#1A1A1A" stroke-width="2"/></svg>';
      CAR_ICON='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(svg);
    }

    function start(){
      var startPt = ROUTE.length ? ROUTE[0] : DEST;
      var map = new mapgl.Map('map', {
        center: startPt, zoom: 18, pitch: 60, rotation: 0, key: KEY, disableHidingPois: false
      });
      try { map.on('styleload', function(){ hideClutter(map); }); } catch(e){}
      hideClutter(map);

      new mapgl.Marker(map, { coordinates: DEST });
      var car = new mapgl.Marker(map, {
        coordinates: startPt, icon: CAR_ICON, size: [48,60], anchor: [24,30], zIndex: 100
      });

      // Remaining route only — the travelled part vanishes as the car advances.
      var casing=null, line=null, lastSeg=-1;
      function drawRemaining(seg, curPt){
        var coords=[curPt];
        for (var j=seg+1;j<ROUTE.length;j++) coords.push(ROUTE[j]);
        if (coords.length < 2) coords = [curPt, DEST];
        if (casing) casing.destroy();
        if (line) line.destroy();
        // Yellow route (brand accent) with a dark casing so it stays visible on 2GIS's yellow roads.
        casing = new mapgl.Polyline(map, { coordinates: coords, width: 15, color: '#6B4E00', zIndex: 4 });
        line   = new mapgl.Polyline(map, { coordinates: coords, width: 8,  color: '#FFCE00', zIndex: 5 });
      }
      drawRemaining(0, startPt);
      post({type:'ready'});
      post({type:'voice', text:'Маршрут построен, начинаем движение'});

      if (ROUTE.length < 2) { post({type:'done'}); return; }

      // Demo speed: natural driving pace (~50 km/h), not teleporting.
      var DEMO = 14; // m/s
      var traveled = 0, lastPost = 0, lastT = performance.now();
      function frame(now){
        var dt = (now-lastT)/1000; lastT = now;
        traveled += DEMO*dt;
        if (traveled >= TOTAL) {
          car.setCoordinates(DEST); map.setCenter(DEST);
          if (casing) casing.destroy(); if (line) line.destroy();
          post({type:'pos', lat:DEST[1], lng:DEST[0], remainingKm:0, etaMin:0, progress:1});
          post({type:'voice', text:'Вы прибыли на место'});
          post({type:'done'});
          return;
        }
        // Voice: announce the next turn ~200 m before it.
        for (var ti=0; ti<TURNS.length; ti++){
          var tn=TURNS[ti];
          if (!tn.done && tn.dist>traveled && (tn.dist-traveled)<=200){
            tn.done=true;
            var mm=Math.max(50, Math.round((tn.dist-traveled)/50)*50);
            post({type:'voice', text:'Через '+mm+' метров поверните '+tn.dir});
            break;
          }
        }
        var s = along(traveled);
        car.setCoordinates(s.pt);
        map.setCenter(s.pt);
        map.setRotation(-s.hd);
        if (s.seg !== lastSeg) { drawRemaining(s.seg, s.pt); lastSeg = s.seg; }
        if (now - lastPost > 500) {
          lastPost = now;
          var remM = TOTAL - traveled;
          post({ type:'pos', lat:s.pt[1], lng:s.pt[0], remainingKm: remM/1000,
                 etaMin: Math.ceil(remM/SPEED/60), progress: traveled/TOTAL });
        }
        requestAnimationFrame(frame);
      }
      requestAnimationFrame(frame);
    }

    if (window.mapgl) start();
    else window.addEventListener('load', function(){
      if (window.mapgl) start(); else post({type:'done'});
    });
  </script>
</body>
</html>
''';
  }
}
