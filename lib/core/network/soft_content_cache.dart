/// In-memory last-good content for soft offline UX (not offline-first DB).
class SoftContentCache<T> {
  SoftContentCache();

  T? _value;
  DateTime? _updatedAt;

  T? get value => _value;
  DateTime? get updatedAt => _updatedAt;
  bool get hasValue => _value != null;

  void put(T value) {
    _value = value;
    _updatedAt = DateTime.now();
  }

  void clear() {
    _value = null;
    _updatedAt = null;
  }
}
