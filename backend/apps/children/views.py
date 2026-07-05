from rest_framework import viewsets

from apps.accounts.permissions import IsParent

from .models import Child
from .serializers import ChildSerializer


class ChildViewSet(viewsets.ModelViewSet):
    """Parent-owned CRUD for children."""

    serializer_class = ChildSerializer
    permission_classes = [IsParent]

    def get_queryset(self):
        return Child.objects.filter(parent__user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(parent=self.request.user.parent_profile)
