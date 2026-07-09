from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="parentprofile",
            name="photo",
            field=models.ImageField(
                blank=True, null=True, upload_to="parents/"
            ),
        ),
    ]
