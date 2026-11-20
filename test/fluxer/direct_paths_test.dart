import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/fluxer/hub/fluxer_direct_paths.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:playback_core/playback_core.dart';
import 'package:playback_emby/playback_emby.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _serverPath = '/media/otro/peliculas/Una película (2012) [imdb=tt1]/Una película (2012).mkv';

class _PlaybackApi extends Fake implements PlaybackApi {
  _PlaybackApi({this.protocol = 'File'});

  final String protocol;

  @override
  Future<Map<String, dynamic>> getPlaybackInfo(
    String itemId, {
    Map<String, dynamic>? requestBody,
    String? userId,
    int? startTimeTicks,
    bool waitForMediaProbe = false,
  }) async =>
      <String, dynamic>{
        'PlaySessionId': 'ps1',
        'MediaSources': <Map<String, dynamic>>[
          <String, dynamic>{
            'Id': 's1',
            'Protocol': protocol,
            'IsRemote': false,
            'Path': _serverPath,
            'Container': 'mkv',
            'SupportsDirectPlay': true,
            'SupportsDirectStream': true,
            'SupportsTranscoding': true,
            'TranscodingUrl': '/videos/1/master.m3u8?MediaSourceId=s1',
            'MediaStreams': <Map<String, dynamic>>[
              <String, dynamic>{'Type': 'Video', 'Codec': 'h264', 'Index': 0},
            ],
          },
        ],
      };

  @override
  String getStreamUrl(
    String itemId, {
    String? mediaSourceId,
    String? audioStreamIndex,
    String? subtitleStreamIndex,
    String? liveStreamId,
  }) =>
      'https://emby.test/Videos/$itemId/stream?MediaSourceId=$mediaSourceId';
}

class _Client extends Fake implements MediaServerClient {
  _Client(this.playbackApi);

  @override
  final PlaybackApi playbackApi;
  @override
  String get baseUrl => 'https://emby.test';
  @override
  String? get accessToken => 'token';
  @override
  String? get userId => 'u1';
  @override
  DeviceInfo get deviceInfo => const DeviceInfo(id: 'd', name: 'test', appName: 'Moonfin', appVersion: '1');
}

Map<String, dynamic> get _item => <String, dynamic>{'Id': '1', 'Type': 'Movie'};

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<UserPreferences>(UserPreferences(store));
    FluxerDirectPaths.install();
    await FluxerDirectPaths.save({
      'url': 'https://emby.test',
      'direct_paths': [
        {'prefix': '/media/otro/', 'url': 'https://otro.test/'},
      ],
    });
  });

  tearDown(() async {
    EmbyMediaStreamResolver.directPathUrl = null;
    await GetIt.instance.reset();
  });

  test('a file under a listed folder is read from the other address with the token', () async {
    final result = await EmbyMediaStreamResolver(_Client(_PlaybackApi())).resolve(_item);

    expect(
      result.streamUrl,
      'https://otro.test/peliculas/Una%20pel%C3%ADcula%20(2012)%20%5Bimdb%3Dtt1%5D/Una%20pel%C3%ADcula%20(2012).mkv',
    );
    expect(result.playMethod, StreamPlayMethod.directPlay);
    expect(result.requestHeaders, {'X-Emby-Token': 'token'});
    expect(result.streamUrl, isNot(contains('api_key')));
  });

  test('other folders, other servers and an empty list stay on the server', () async {
    expect(FluxerDirectPaths.urlFor('https://emby.test', '/mnt/storage/peli.mkv'), isNull);
    expect(FluxerDirectPaths.urlFor('https://otro-emby.test', _serverPath), isNull);

    await FluxerDirectPaths.save({'url': 'https://emby.test', 'direct_paths': []});
    final result = await EmbyMediaStreamResolver(_Client(_PlaybackApi())).resolve(_item);
    expect(result.streamUrl, startsWith('https://emby.test/Videos/1/stream'));
    expect(result.requestHeaders, isEmpty);
  });

  test('a forced transcode or a remote source keeps the server', () async {
    final transcode = await EmbyMediaStreamResolver(_Client(_PlaybackApi())).resolve(_item, enableDirectPlay: false);
    expect(transcode.streamUrl, startsWith('https://emby.test/'));
    expect(transcode.requestHeaders, isEmpty);

    final remote = await EmbyMediaStreamResolver(_Client(_PlaybackApi(protocol: 'Http'))).resolve(_item);
    expect(remote.requestHeaders, isEmpty);
  });
}
