import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/route_outlet.dart';
import 'visit_providers.dart';
import '../../catalog/presentation/catalog_screen.dart';

// "1 ч 05 мин" / "5 мин" / "менее минуты" — используется и для тикающего
// таймера активного визита, и для итоговой длительности после завершения
String _formatElapsed(Duration d) {
  if (d.inMinutes < 1) return 'менее минуты';
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours > 0) return '$hours ч ${minutes.toString().padLeft(2, '0')} мин';
  return '$minutes мин';
}

class OutletDetailScreen extends ConsumerStatefulWidget {
  final RouteOutlet outlet;
  final int plannedOrder;

  const OutletDetailScreen({
    super.key,
    required this.outlet,
    this.plannedOrder = 1,
  });

  @override
  ConsumerState<OutletDetailScreen> createState() => _OutletDetailScreenState();
}

class _OutletDetailScreenState extends ConsumerState<OutletDetailScreen> {
  // Тикающий таймер, пока визит активен — просто дёргает setState раз в
  // минуту, чтобы обновить надпись "начат N мин назад"; сама длительность
  // считается из VisitState.elapsed по текущему времени, тут ничего не хранится
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visitState = ref.watch(visitProvider);

    // Пока визит идёт (начат, но не завершён) — обновляем экран раз в минуту
    if (visitState.isSuccess && !visitState.isEnded && _ticker == null) {
      _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }

    ref.listen(visitProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: colorScheme.error,
          ),
        );
      }
      if (next.isSuccess && next.startedAt != null && !next.isEnded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Визит начат успешно!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      if (next.isEnded && next.elapsed != null) {
        _ticker?.cancel();
        _ticker = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Визит завершён • ${_formatElapsed(next.elapsed!)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Торговая точка',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Основная информация ──
            _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.outlet.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.outlet.address != null &&
                      widget.outlet.address!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.outlet.address!,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  _StatusBadge(status: widget.outlet.status),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Контакты ──
            if (widget.outlet.contacts.isNotEmpty) ...[
              _SectionTitle('Контакты'),
              const SizedBox(height: 8),
              _InfoCard(
                child: Column(
                  children: widget.outlet.contacts.asMap().entries.map((entry) {
                    final i = entry.key;
                    final contact = entry.value;
                    return Column(
                      children: [
                        _ContactRow(contact: contact),
                        if (i < widget.outlet.contacts.length - 1)
                          Divider(
                            height: 16,
                            color: colorScheme.outlineVariant,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Статус визита ──
            if (visitState.isSuccess) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visitState.isEnded
                                ? 'Визит завершён'
                                : 'Визит начат',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          if (visitState.elapsed != null)
                            Text(
                              visitState.isEnded
                                  ? 'Длительность: ${_formatElapsed(visitState.elapsed!)}'
                                  : 'Идёт: ${_formatElapsed(visitState.elapsed!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── История визитов ──
            _SectionTitle('История визитов'),
            const SizedBox(height: 8),
            _VisitsHistory(outletId: widget.outlet.id),
            const SizedBox(height: 16),

            // ── Кнопка начать визит ──
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: visitState.isLoading || visitState.isSuccess
                    ? null
                    : () async {
                        await ref
                            .read(visitProvider.notifier)
                            .startVisit(
                              outletId: widget.outlet.id,
                              plannedOrder: widget.plannedOrder,
                            );
                      },
                icon: visitState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        visitState.isSuccess
                            ? Icons.check_rounded
                            : Icons.play_arrow_rounded,
                      ),
                label: Text(
                  visitState.isLoading
                      ? 'Создаём визит...'
                      : visitState.isSuccess
                      ? 'Визит начат'
                      : 'Начать визит',
                  style: const TextStyle(fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: visitState.isSuccess
                      ? Colors.grey
                      : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            if (visitState.isSuccess && visitState.visitId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.outlet.counterparties.isEmpty
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'У точки нет привязанного контрагента',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CatalogScreen(
                              outletId: widget.outlet.id,
                              outletName: widget.outlet.name,
                              visitId: visitState.visitId!,
                              counterpartyId:
                                  widget.outlet.counterparties.first,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.list_alt_rounded),
                  label: const Text(
                    'Открыть каталог',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],

            if (visitState.isSuccess && !visitState.isEnded) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmEndVisit(context),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text(
                    'Завершить визит',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Подтверждение перед завершением визита. Пока без выбора статуса/причины —
  // это уходит только в локальное состояние экрана, не на сервер (см.
  // комментарий у VisitNotifier.endVisit), так что собирать доп. данные,
  // которые всё равно никуда не сохранятся, было бы нечестно по отношению
  // к пользователю
  void _confirmEndVisit(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Завершить визит?'),
        content: const Text(
          'Приложение зафиксирует, сколько времени вы провели на точке.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(visitProvider.notifier).endVisit();
            },
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// История визитов
// ──────────────────────────────────────────

class _VisitsHistory extends ConsumerWidget {
  final String outletId;
  const _VisitsHistory({required this.outletId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(outletVisitsProvider(outletId));
    final colorScheme = Theme.of(context).colorScheme;

    if (state.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state.visits.isEmpty) {
      return _InfoCard(
        child: Row(
          children: [
            Icon(
              Icons.history_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Визитов ещё не было',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return _InfoCard(
      child: Column(
        children: state.visits.asMap().entries.map((entry) {
          final i = entry.key;
          final visit = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: visit.isCompleted
                            ? Colors.green.shade50
                            : Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        visit.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.play_circle_rounded,
                        color: visit.isCompleted ? Colors.green : Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visit.formattedDate,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            visit.isCompleted
                                ? 'Завершён • ${visit.duration}'
                                : 'В процессе',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      visit.id.substring(0, 8),
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < state.visits.length - 1)
                Divider(height: 1, color: colorScheme.outlineVariant),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Контакт
// ──────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  final RouteOutletContact contact;
  const _ContactRow({required this.contact});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_rounded,
            color: colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    contact.fullName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (contact.isDecisionMaker) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ЛПР',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (contact.phoneNumber.isNotEmpty)
                Text(
                  contact.phoneNumber,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (contact.phoneNumber.isNotEmpty)
          IconButton(
            icon: Icon(Icons.phone_rounded, color: colorScheme.primary),
            onPressed: () async {
              final uri = Uri(scheme: 'tel', path: contact.phoneNumber);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────
// Вспомогательные виджеты
// ──────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  String get _label {
    switch (status) {
      case 'ACCEPTED':
        return 'Принята';
      case 'PENDING':
        return 'В ожидании';
      case 'REJECTED':
        return 'Отклонена';
      default:
        return status;
    }
  }

  Color get _color {
    switch (status) {
      case 'ACCEPTED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}
