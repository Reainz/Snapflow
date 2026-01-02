Future<void> asyncFn() async {}

void main() {
  void Function()? cb;
  cb = asyncFn;
  cb.call();
}
