Future<void> foo() async {}

void main() {
  void Function() cb = foo;
  cb();
}
