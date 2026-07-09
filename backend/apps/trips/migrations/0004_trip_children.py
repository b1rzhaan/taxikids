from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("children", "0002_child_grade_child_is_primary"),
        ("trips", "0003_trip_payment_method"),
    ]

    operations = [
        migrations.AddField(
            model_name="trip",
            name="children",
            field=models.ManyToManyField(
                blank=True,
                related_name="shared_trips",
                to="children.child",
            ),
        ),
    ]
