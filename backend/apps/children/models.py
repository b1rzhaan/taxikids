from django.db import models

from apps.accounts.models import ParentProfile


class Child(models.Model):
    parent = models.ForeignKey(
        ParentProfile, on_delete=models.CASCADE, related_name="children"
    )
    full_name = models.CharField(max_length=120)
    birth_date = models.DateField(null=True, blank=True)
    school = models.CharField(max_length=160, blank=True)
    grade = models.CharField("Класс", max_length=20, blank=True)  # напр. "4 класс"
    is_primary = models.BooleanField(default=False)  # основной ребёнок
    photo = models.ImageField(upload_to="children/", null=True, blank=True)
    note_for_driver = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "children"
        ordering = ["full_name"]

    def __str__(self) -> str:
        return self.full_name

    @property
    def age(self) -> int | None:
        if not self.birth_date:
            return None
        from datetime import date

        today = date.today()
        return today.year - self.birth_date.year - (
            (today.month, today.day) < (self.birth_date.month, self.birth_date.day)
        )
