import datetime as dt

from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.trips.tasks import generate_for_date


class Command(BaseCommand):
    help = "Generate concrete Trips from active recurring plans for a date."

    def add_arguments(self, parser):
        parser.add_argument("--days-ahead", type=int, default=1)

    def handle(self, *args, **options):
        target = timezone.localdate() + dt.timedelta(days=options["days_ahead"])
        created = generate_for_date(target)
        self.stdout.write(self.style.SUCCESS(f"Created {created} trips for {target}"))
