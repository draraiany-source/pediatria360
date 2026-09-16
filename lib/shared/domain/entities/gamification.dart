import 'package:equatable/equatable.dart';

/// Ação que rende XP.
///
/// Os valores ficam no servidor (`awardXp`); esta lista existe para a tela
/// explicar ao usuário como pontuar. Se o cliente definisse o XP, bastaria
/// alterar um número na memória para liderar o ranking.
enum XpAction {
  growthRecorded,
  vaccineMarked,
  lessonCompleted,
  courseCompleted,
  articleRead,
  aiQuestion,
  dailyOpen,
  challengeCompleted;

  String get label => switch (this) {
        XpAction.growthRecorded => 'Registrar uma medição',
        XpAction.vaccineMarked => 'Marcar uma vacina aplicada',
        XpAction.lessonCompleted => 'Concluir uma aula',
        XpAction.courseCompleted => 'Concluir um curso',
        XpAction.articleRead => 'Ler um artigo',
        XpAction.aiQuestion => 'Tirar uma dúvida com a IA',
        XpAction.dailyOpen => 'Abrir o app no dia',
        XpAction.challengeCompleted => 'Concluir um desafio',
      };

  /// Valor exibido na tela. O servidor tem a palavra final.
  int get displayXp => switch (this) {
        XpAction.growthRecorded => 20,
        XpAction.vaccineMarked => 30,
        XpAction.lessonCompleted => 15,
        XpAction.courseCompleted => 100,
        XpAction.articleRead => 5,
        XpAction.aiQuestion => 3,
        XpAction.dailyOpen => 5,
        XpAction.challengeCompleted => 50,
      };
}

/// Uma medalha conquistável.
class Badge extends Equatable {
  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.tier,
    this.requirement,
  });

  factory Badge.fromMap(String id, Map<String, dynamic> map) => Badge(
        id: id,
        name: (map['name'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        icon: (map['icon'] as String?) ?? 'star',
        tier: BadgeTier.fromName(map['tier'] as String?),
        requirement: map['requirement'] as String?,
      );

  final String id;
  final String name;
  final String description;
  final String icon;
  final BadgeTier tier;

  /// Texto do critério, em linguagem corrente.
  final String? requirement;

  @override
  List<Object?> get props => <Object?>[id, tier];
}

enum BadgeTier {
  bronze,
  silver,
  gold,
  platinum;

  static BadgeTier fromName(String? value) => BadgeTier.values.firstWhere(
        (BadgeTier t) => t.name == value,
        orElse: () => BadgeTier.bronze,
      );

  String get label => switch (this) {
        BadgeTier.bronze => 'Bronze',
        BadgeTier.silver => 'Prata',
        BadgeTier.gold => 'Ouro',
        BadgeTier.platinum => 'Platina',
      };
}

/// Medalha já conquistada por alguém.
class EarnedBadge extends Equatable {
  const EarnedBadge({required this.badgeId, required this.earnedAt});

  final String badgeId;
  final DateTime earnedAt;

  @override
  List<Object?> get props => <Object?>[badgeId, earnedAt];
}

/// Sequência de dias de uso.
///
/// ## Por que a sequência é frouxa de propósito
///
/// Um app de saúde infantil não pode punir quem passou a noite no
/// pronto-socorro e esqueceu de abrir o aplicativo. A sequência tolera **um
/// dia perdido por semana** sem zerar. Streak agressiva gera ansiedade, e
/// ansiedade é exatamente o que não se quer somar à vida de quem cuida de uma
/// criança doente.
class Streak extends Equatable {
  const Streak({
    required this.currentDays,
    required this.longestDays,
    this.lastActiveDate,
    this.graceUsedThisWeek = false,
  });

  final int currentDays;
  final int longestDays;
  final DateTime? lastActiveDate;

  /// `true` se a tolerância semanal já foi usada.
  final bool graceUsedThisWeek;

  /// Calcula o novo estado a partir de uma abertura hoje.
  Streak registerActivity({DateTime? at}) {
    final DateTime now = at ?? DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    if (lastActiveDate == null) {
      return Streak(
        currentDays: 1,
        longestDays: longestDays < 1 ? 1 : longestDays,
        lastActiveDate: today,
      );
    }

    final DateTime last = DateTime(
      lastActiveDate!.year,
      lastActiveDate!.month,
      lastActiveDate!.day,
    );

    final int gap = today.difference(last).inDays;

    // Mesmo dia: nada muda.
    if (gap == 0) return this;

    // Dia seguinte: soma.
    if (gap == 1) {
      final int next = currentDays + 1;
      return Streak(
        currentDays: next,
        longestDays: next > longestDays ? next : longestDays,
        lastActiveDate: today,
        graceUsedThisWeek: graceUsedThisWeek,
      );
    }

    // Faltou um dia e ainda há tolerância: mantém a sequência.
    if (gap == 2 && !graceUsedThisWeek) {
      final int next = currentDays + 1;
      return Streak(
        currentDays: next,
        longestDays: next > longestDays ? next : longestDays,
        lastActiveDate: today,
        graceUsedThisWeek: true,
      );
    }

    // Recomeça.
    return Streak(
      currentDays: 1,
      longestDays: longestDays,
      lastActiveDate: today,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[currentDays, longestDays, lastActiveDate, graceUsedThisWeek];
}

/// Uma posição no ranking.
class LeaderboardEntry extends Equatable {
  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.xp,
    required this.position,
    this.photoUrl,
    this.isCurrentUser = false,
  });

  final String uid;

  /// Primeiro nome + inicial do sobrenome. O ranking não expõe nome completo
  /// nem e-mail — é uma lista pública dentro de um app de saúde.
  final String displayName;

  final int xp;
  final int position;
  final String? photoUrl;
  final bool isCurrentUser;

  @override
  List<Object?> get props => <Object?>[uid, xp, position];
}

/// Desafio com prazo.
class Challenge extends Equatable {
  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.xpReward,
    required this.target,
    this.progress = 0,
    this.endsAt,
    this.completed = false,
  });

  final String id;
  final String title;
  final String description;
  final int xpReward;

  /// Quantas vezes a ação precisa acontecer.
  final int target;

  final int progress;
  final DateTime? endsAt;
  final bool completed;

  double get ratio => target == 0 ? 0 : (progress / target).clamp(0, 1);

  int? get daysLeft => endsAt == null
      ? null
      : endsAt!.difference(DateTime.now()).inDays;

  @override
  List<Object?> get props => <Object?>[id, progress, completed];
}
