from rest_framework import serializers

from .models import Child


class ChildSerializer(serializers.ModelSerializer):
    age = serializers.IntegerField(read_only=True)

    class Meta:
        model = Child
        fields = [
            "id",
            "full_name",
            "birth_date",
            "age",
            "school",
            "grade",
            "is_primary",
            "photo",
            "note_for_driver",
            "is_active",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]
