import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../error/exceptions.dart';
import '../utils/result.dart';
import 'app_logger.dart';


/// Referência a um vídeo hospedado no Bunny Stream.
class BunnyVideo {
  const BunnyVideo({
    required this.guid,
    required this.title,
    this.durationSeconds = 0,
    this.thumbnailUrl,
    this.status = BunnyVideoStatus.ready,
  });

  factory BunnyVideo.fromMap(Map<String, dynamic> map) => BunnyVideo(
        guid: (map['guid'] as String?) ?? '',
        title: (map['title'] as String?) ?? '',
        durationSeconds: (map['length'] as num?)?.toInt() ?? 0,
        thumbnailUrl: map['thumbnailUrl'] as String?,
        status: BunnyVideoStatus.fromCode(
          (map['status'] as num?)?.toInt() ?? 4,
        ),
      );

  final String guid;
  final String title;
  final int durationSeconds;
  final String? thumbnailUrl;
  final BunnyVideoStatus status;

  Duration get duration => Duration(seconds: durationSeconds);
}

/// Estágio do processamento no Bunny.
///
/// Um vídeo recém-enviado leva alguns minutos até ficar disponível em HLS.
/// A tela precisa distinguir "ainda processando" de "quebrado" — são conversas
/// diferentes com quem publicou.
enum BunnyVideoStatus {
  queued,
  processing,
  encoding,
  ready,
  failed;

  static BunnyVideoStatus fromCode(int code) => switch (code) {
        0 || 1 => BunnyVideoStatus.queued,
        2 => BunnyVideoStatus.processing,
        3 => BunnyVideoStatus.encoding,
        4 => BunnyVideoStatus.ready,
        _ => BunnyVideoStatus.failed,
      };

  bool get isPlayable => this == BunnyVideoStatus.ready;

  String get label => switch (this) {
        BunnyVideoStatus.queued => 'Na fila',
        BunnyVideoStatus.processing => 'Processando',
        BunnyVideoStatus.encoding => 'Convertendo',
        BunnyVideoStatus.ready => 'Disponível',
        BunnyVideoStatus.failed => 'Falhou',
      };
}

/// Acesso ao Bunny Stream e ao Bunny Storage.
///
/// ## Divisão de responsabilidade com o servidor
///
/// A **chave de API do Bunny não fica no aplicativo**. Ela permite criar,
/// apagar e listar vídeos da biblioteca inteira — embutida num APK, qualquer
/// pessoa apagaria o acervo.
///
/// O que o app faz direto: montar URLs públicas de reprodução (HLS e
/// miniatura), que são apenas concatenação de hostname e GUID.
///
/// O que passa por Cloud Function: criar o vídeo, obter a URL assinada de
/// upload, e gerar token de acesso para conteúdo pago.
class BunnyService {
  BunnyService({
    required Dio dio,
    required FirebaseFunctions functions,
  })  : _dio = dio,
        _functions = functions;

  final Dio _dio;
  final FirebaseFunctions _functions;

  bool get isConfigured => AppConfig.hasBunnyConfigured;

  // ------------------------------------------------------------ Reprodução

  /// URL do manifesto HLS.
  ///
  /// HLS adapta a qualidade à banda disponível — essencial para quem assiste
  /// no 4G com sinal instável, que é a maioria.
  String hlsUrl(String videoGuid) =>
      'https://${AppConfig.bunnyCdnHostname}/$videoGuid/playlist.m3u8';

  /// URL de um MP4 de qualidade fixa. Usada quando o usuário força uma
  /// resolução ou baixa a aula para ver offline.
  String mp4Url(String videoGuid, {int height = 720}) =>
      'https://${AppConfig.bunnyCdnHostname}/$videoGuid/play_$height.mp4';

  /// Miniatura gerada pelo Bunny.
  String thumbnailUrl(String videoGuid) =>
      'https://${AppConfig.bunnyCdnHostname}/$videoGuid/thumbnail.jpg';

  /// Pré-visualização animada (WebP), exibida ao passar o dedo sobre o card.
  String previewUrl(String videoGuid) =>
      'https://${AppConfig.bunnyCdnHostname}/$videoGuid/preview.webp';

  /// Arquivo no Bunny Storage (PDFs, áudios, imagens de conteúdo).
  String storageUrl(String path) {
    final String clean = path.startsWith('/') ? path.substring(1) : path;
    return 'https://${AppConfig.bunnyStorageHostname}/$clean';
  }

  /// URL de reprodução para conteúdo restrito.
  ///
  /// Aulas de curso pago usam token com expiração: o link copiado do inspetor
  /// deixa de funcionar em minutos. Conteúdo livre dispensa a chamada.
  Future<Result<String>> signedPlaybackUrl({
    required String videoGuid,
    Duration validity = const Duration(hours: 4),
  }) =>
      guard(() async {
        final HttpsCallableResult<dynamic> response = await _functions
            .httpsCallable('signBunnyPlayback')
            .call(<String, dynamic>{
          'videoGuid': videoGuid,
          'expiresInSeconds': validity.inSeconds,
        });

        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>);

        final String? url = data['url'] as String?;
        if (url == null || url.isEmpty) {
          throw const ServerException('URL de reprodução não recebida.');
        }
        return url;
      });

  // ----------------------------------------------------------------- Upload

  /// Envia um vídeo.
  ///
  /// Fluxo em três passos, porque o app nunca toca na chave do Bunny:
  /// 1. A Function cria a entrada na biblioteca e devolve GUID + URL assinada.
  /// 2. O app faz `PUT` dos bytes direto no Bunny (sem passar pelo servidor —
  ///    um vídeo de 500 MB trafegando por Cloud Function seria caro e lento).
  /// 3. O Bunny processa; o app consulta o status até ficar pronto.
  Future<Result<BunnyVideo>> uploadVideo({
    required String title,
    required Stream<List<int>> data,
    required int contentLength,
    String? collectionId,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) =>
      guard(() async {
        final HttpsCallableResult<dynamic> created = await _functions
            .httpsCallable('createBunnyVideo')
            .call(<String, dynamic>{
          'title': title,
          if (collectionId != null) 'collectionId': collectionId,
        });

        final Map<String, dynamic> info =
            Map<String, dynamic>.from(created.data as Map<dynamic, dynamic>);

        final String guid = (info['guid'] as String?) ?? '';
        final String uploadUrl = (info['uploadUrl'] as String?) ?? '';
        final String signature = (info['signature'] as String?) ?? '';
        final int expires = (info['expires'] as num?)?.toInt() ?? 0;

        if (guid.isEmpty || uploadUrl.isEmpty) {
          throw const ServerException('Não foi possível preparar o envio.');
        }

        await _dio.put<void>(
          uploadUrl,
          data: data,
          options: Options(
            headers: <String, dynamic>{
              'Content-Type': 'application/octet-stream',
              Headers.contentLengthHeader: contentLength,
              if (signature.isNotEmpty) 'AuthorizationSignature': signature,
              if (expires > 0) 'AuthorizationExpire': expires,
              if (signature.isNotEmpty) 'VideoId': guid,
              if (signature.isNotEmpty)
                'LibraryId': AppConfig.bunnyStreamLibraryId,
            },
            // Upload longo: o timeout global de 30s do Dio mataria o envio.
            sendTimeout: const Duration(minutes: 30),
            receiveTimeout: const Duration(minutes: 5),
          ),
          onSendProgress: onProgress,
          cancelToken: cancelToken,
        );

        return BunnyVideo(
          guid: guid,
          title: title,
          status: BunnyVideoStatus.queued,
        );
      });

  /// Consulta o estágio de processamento.
  Future<Result<BunnyVideo>> videoStatus(String videoGuid) =>
      guard(() async {
        final HttpsCallableResult<dynamic> response = await _functions
            .httpsCallable('getBunnyVideo')
            .call(<String, dynamic>{'videoGuid': videoGuid});

        return BunnyVideo.fromMap(
          Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>),
        );
      });

  /// Aguarda o processamento terminar, com intervalo fixo.
  ///
  /// O Bunny oferece webhook, que é o caminho certo em produção (a Function
  /// `bunnyWebhook` já grava o status no Firestore). Este polling existe para
  /// a tela de upload do painel, onde o autor está olhando e quer retorno.
  Stream<BunnyVideo> watchProcessing(
    String videoGuid, {
    Duration interval = const Duration(seconds: 6),
    Duration timeout = const Duration(minutes: 30),
  }) async* {
    final DateTime deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final Result<BunnyVideo> result = await videoStatus(videoGuid);

      final BunnyVideo? video = result.valueOrNull;
      if (video != null) {
        yield video;
        if (video.status.isPlayable ||
            video.status == BunnyVideoStatus.failed) {
          return;
        }
      } else {
        await AppLogger.error(
          result.failureOrNull ?? 'status desconhecido',
          StackTrace.current,
          reason: 'bunny.watchProcessing',
        );
      }

      await Future<void>.delayed(interval);
    }
  }

  Future<Result<void>> deleteVideo(String videoGuid) => guard(() async {
        await _functions
            .httpsCallable('deleteBunnyVideo')
            .call(<String, dynamic>{'videoGuid': videoGuid});
      });
}
