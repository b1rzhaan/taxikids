"""Reusable DRF permission classes built on the single-role model."""
from rest_framework.permissions import BasePermission

from .models import Role


class _RolePermission(BasePermission):
    role: str | None = None

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and user.role == self.role)


class IsParent(_RolePermission):
    role = Role.PARENT


class IsDriver(_RolePermission):
    role = Role.DRIVER


class IsOperator(_RolePermission):
    role = Role.OPERATOR


class IsAdmin(_RolePermission):
    role = Role.ADMIN


class IsAccountant(_RolePermission):
    role = Role.ACCOUNTANT


class IsAdminOrOperator(BasePermission):
    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and user.role in (Role.ADMIN, Role.OPERATOR)
        )


class IsFinanceRole(BasePermission):
    """Money-related endpoints: accountant and admin only (operator excluded)."""

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and user.role in (Role.ADMIN, Role.ACCOUNTANT)
        )


class IsStaffRole(BasePermission):
    """Any internal cabinet user (operator/admin/accountant)."""

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and user.role in (Role.OPERATOR, Role.ADMIN, Role.ACCOUNTANT)
        )
