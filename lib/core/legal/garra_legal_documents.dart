/// In-app legal copy sourced from `docs/legal/` in the product repository.
/// Backend `/legal/*` HTML pages are staging stubs and are not shown in-app.
enum GarraLegalDocument {
  privacy,
  terms,
  community,
}

extension GarraLegalDocumentCopy on GarraLegalDocument {
  String get title => switch (this) {
        GarraLegalDocument.privacy => 'Política de privacidad',
        GarraLegalDocument.terms => 'Términos de uso',
        GarraLegalDocument.community => 'Normas de comunidad',
      };

  String get body => switch (this) {
        GarraLegalDocument.privacy => _privacyBody,
        GarraLegalDocument.terms => _termsBody,
        GarraLegalDocument.community => _communityBody,
      };
}

const _privacyBody = '''
Garra Digital es una comunidad independiente de hinchas de Universitario de Deportes. No es una aplicación oficial del club.

Datos que tratamos

• Cuenta: correo, usuario, nombre visible y credenciales de acceso.
• Perfil: ciudad, país, avatar, visibilidad e intereses que elijas compartir.
• Contenido: publicaciones, comentarios, reacciones y archivos que subas.
• Dispositivo: tokens de notificaciones push y datos técnicos básicos para operar la app.
• Ubicación: solo cuando uses funciones que la solicitan explícitamente (mapa, check-in).
• Analítica y diagnósticos: solo si activas esos consentimientos en Privacidad.

Para qué los usamos

• Autenticarte y mantener tu sesión segura.
• Mostrar comunidad, partidos, marketplace, solidaria y eventos.
• Enviar notificaciones que habilitaste.
• Moderar abusos y procesar eliminación de cuenta.
• Mejorar estabilidad cuando aceptaste diagnósticos o analítica.

Compartimos datos con proveedores que nos ayudan a operar el servicio (hosting, almacenamiento de medios, autenticación, mapas y mensajería push), siempre dentro de lo necesario para prestar Garra.

Tus decisiones

Puedes revisar consentimientos en Ajustes → Privacidad, exportar datos o solicitar eliminación de cuenta desde Ajustes.

Si tienes dudas, escríbenos desde Ayuda y soporte.
''';

const _termsBody = '''
Garra Digital es una plataforma comunitaria independiente para hinchas. No representa una aplicación oficial del club.

Cuenta

• Debes registrar información veraz.
• Eres responsable del uso de tu sesión en tu dispositivo.
• Podemos suspender cuentas que violen las normas o abusen del servicio.

Uso aceptable

Respeta las normas de comunidad. No publiques contenido ilegal, no acoses a otras personas ni intentes acceder sin autorización.

Contenido

Conservas tus derechos sobre lo que publicas. Nos concedes la licencia necesaria para alojarlo, mostrarlo y moderarlo dentro de Garra. Tras eliminar tu cuenta, dejamos de atribuirte contenido público según la política de eliminación.

Servicio en evolución

Garra puede cambiar, pausar funciones o entrar en mantenimiento. El servicio se ofrece en la medida en que esté disponible.

Cambios

Podemos actualizar estos términos. Si continúas usando Garra después de un aviso razonable, aceptas la versión vigente cuando la ley lo permita.
''';

const _communityBody = '''
Principios

1. Respeto entre hinchas.
2. Cero violencia, amenazas o discriminación.
3. Cero spam, estafas o publicidad engañosa.
4. No compartas datos privados de terceros (doxxing).
5. Contenido sexual explícito o ilegal: prohibido.
6. Reporta abusos; no tomes la justicia por tu cuenta.

Moderación

Garra puede ocultar, eliminar o restringir contenido y cuentas que violen estas normas. Las decisiones quedan registradas para operación interna.

Marketplace, Solidaria y eventos

Las publicaciones comerciales o de ayuda deben ser honestas. Las campañas de Garra Solidaria pueden requerir verificación.

Reincidencia

El abuso repetido puede terminar en suspensión o eliminación de cuenta.
''';
