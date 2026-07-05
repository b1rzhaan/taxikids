from rest_framework.pagination import PageNumberPagination


class DefaultPagination(PageNumberPagination):
    """Standard paging, but clients may ask for a bigger page (history views)."""

    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 200
