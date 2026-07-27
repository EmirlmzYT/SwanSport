class PageRequest {
  const PageRequest({
    this.page = 1,
    this.pageSize = 20,
  });

  final int page;
  final int pageSize;
}
