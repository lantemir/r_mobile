// Данные бренда (тенанта), которые отдаёт общий сервис rmt-api-ce
// по короткому домену из логина (GET /api/v1/tenant-settings?domain=...)
class TenantInfo {
  final String tenantName;
  final String shortName;
  final bool isDisabled;
  final String serviceEndpointUrl;

  const TenantInfo({
    required this.tenantName,
    required this.shortName,
    required this.isDisabled,
    required this.serviceEndpointUrl,
  });
}
