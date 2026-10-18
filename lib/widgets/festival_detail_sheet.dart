import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/festival.dart';

class FestivalDetailSheet extends StatelessWidget {
  const FestivalDetailSheet({
    super.key,
    required this.festival,
    required this.referenceDate,
  });

  final Festival festival;
  final DateTime referenceDate;

  static Future<void> show(
    BuildContext context, {
    required Festival festival,
    required DateTime referenceDate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FestivalDetailSheet(
        festival: festival,
        referenceDate: referenceDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = festival.statusAt(referenceDate);
    final statusText = festival.statusBadgeText(referenceDate);
    final statusColor = switch (status) {
      FestivalStatus.ongoing => const Color(0xFF16A34A),
      FestivalStatus.upcoming => const Color(0xFF2563EB),
      FestivalStatus.ended => const Color(0xFF64748B),
    };

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                  children: [
                    // 상단 배지 행
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: festival.region.baseColor.withValues(
                              alpha: 0.16,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${festival.region.fullName} · ${festival.cityOrDistrict}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: festival.region.baseColor.withValues(
                                alpha: 0.95,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            festival.category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 축제 제목
                    Text(
                      festival.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      festival.summary,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 주요 정보 박스
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.calendar_month_rounded,
                            label: '개최 기간',
                            value: festival.formattedPeriod,
                          ),
                          const Divider(height: 20),
                          _InfoRow(
                            icon: Icons.place_rounded,
                            label: '개최 장소',
                            value: festival.venue,
                          ),
                          const Divider(height: 20),
                          _InfoRow(
                            icon: Icons.map_outlined,
                            label: '상세 주소',
                            value: festival.address,
                            trailing: IconButton(
                              tooltip: '주소 복사',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.copy_rounded, size: 17),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: festival.address),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('주소가 클립보드에 복사되었습니다.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ),
                          const Divider(height: 20),
                          _InfoRow(
                            icon: Icons.confirmation_number_outlined,
                            label: '이용 요금',
                            value: festival.feeInfo,
                          ),
                          if (festival.tel.isNotEmpty) ...[
                            const Divider(height: 20),
                            _InfoRow(
                              icon: Icons.call_outlined,
                              label: '문의 전화',
                              value: festival.tel,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 축제 상세 소개
                    const Text(
                      '축제 소개',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      festival.description,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF334155),
                        height: 1.6,
                      ),
                    ),

                    if (festival.highlights.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        '주요 프로그램 & 즐길거리',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...festival.highlights.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
