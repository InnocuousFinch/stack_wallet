enum EpicCashExceptionType { generic, serializeResponseError }

class EpicCashException implements Exception {
  String errorMessage;
  EpicCashExceptionType type;
  EpicCashException(this.errorMessage, this.type);

  @override
  String toString() {
    return errorMessage;
  }
}

class EpicCashResponse<T> {
  late final T? value;
  late final EpicCashException? exception;

  EpicCashResponse({this.value, this.exception});

  @override
  String toString() {
    return "{error: $exception, value: $value}";
  }
}
