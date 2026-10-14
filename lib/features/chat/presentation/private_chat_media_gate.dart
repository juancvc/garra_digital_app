/// Must remain disabled while private chat images are served by public R2 URLs.
/// Backend independently rejects direct-chat media attachments by default.
const privateChatAttachmentsEnabled = bool.fromEnvironment(
  'PRIVATE_CHAT_ATTACHMENTS_ENABLED',
  defaultValue: false,
);
