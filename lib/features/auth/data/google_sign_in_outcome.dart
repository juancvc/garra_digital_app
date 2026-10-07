/// Result of the native Google account picker + Firebase credential step.
sealed class GoogleSignInOutcome {
  const GoogleSignInOutcome();

  const factory GoogleSignInOutcome.success(String idToken) =
      GoogleSignInOutcomeSuccess;

  const factory GoogleSignInOutcome.cancelled() = GoogleSignInOutcomeCancelled;

  const factory GoogleSignInOutcome.failure(String message) =
      GoogleSignInOutcomeFailure;
}

final class GoogleSignInOutcomeSuccess extends GoogleSignInOutcome {
  const GoogleSignInOutcomeSuccess(this.idToken);

  final String idToken;
}

final class GoogleSignInOutcomeCancelled extends GoogleSignInOutcome {
  const GoogleSignInOutcomeCancelled();
}

final class GoogleSignInOutcomeFailure extends GoogleSignInOutcome {
  const GoogleSignInOutcomeFailure(this.message);

  final String message;
}
