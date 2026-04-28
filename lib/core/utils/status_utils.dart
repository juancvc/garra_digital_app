String translateMatchStatus(String status) {
  switch (status) {
    case 'OPEN_FOR_PREDICTION':
      return 'Abierto para pronóstico';
    case 'CLOSED':
      return 'Cerrado';
    case 'FINISHED':
      return 'Finalizado';
    default:
      return status;
  }
}

String translatePredictionStatus(String status) {
  switch (status) {
    case 'REGISTERED':
      return 'Registrado';
    case 'SCORED':
      return 'Puntuado';
    default:
      return status;
  }
}