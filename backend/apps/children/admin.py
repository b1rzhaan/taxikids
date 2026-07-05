from django.contrib import admin

from .models import Child


@admin.register(Child)
class ChildAdmin(admin.ModelAdmin):
    list_display = ["full_name", "parent", "school", "age", "is_active"]
    list_filter = ["is_active"]
    search_fields = ["full_name", "school"]
