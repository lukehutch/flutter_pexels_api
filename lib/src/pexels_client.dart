import 'dart:convert';

import 'package:http/http.dart' as http;

import 'pexels_collection.dart';
import 'pexels_endpoints.dart';
import 'pexels_orientation.dart';
import 'pexels_image_formats.dart';
import 'pexels_photo.dart';
import 'pexels_quota.dart';
import 'pexels_search_result.dart';
import 'pexels_sources.dart';
import 'pexels_video.dart';

class PexelsClient {
  static Quota _quota = Quota();
  final String apiKey;

  // constructor.
  PexelsClient(this.apiKey);

  Future<String?> _getData(String url) async {
    var resp = await http.get(Uri.parse(url), headers: {
      'Authorization': apiKey,
    });

    var data;
    if (resp.statusCode == 200) {
      data = await resp.body;
      _quota = Quota(
          remainingRequestsPerMonth:
              int.tryParse(resp.headers['x-ratelimit-remaining'] ?? ''));
    }

    return data;
  }

  Future<Quota> getQuota() async => _quota;

  // Photo

  Future<PexelsPhoto?> _getPhotoRandom() async {
    var url = Endpoints.photoRandom();

    String? data = await _getData(url);

    if (data == null) return null;

    var o = jsonDecode(data);

    var photoData = o['photos'][0];
    // extract data
    return _buildPhoto(photoData);
  }

  Future<PexelsPhoto?> _getPhotoFromID(int id) async {
    var url = Endpoints.photo(id);

    String? data = await _getData(url);

    if (data == null) return null;
    var photoData = jsonDecode(data);
    // extract data
    return _buildPhoto(photoData);
  }

  PexelsPhoto? _buildPhoto(photoData) {
    // extract data
    var src = photoData['src'];
    if (src != null) {
      var sources = <String, PhotoSource>{};
      ImageFormats.values.forEach((size) {
        var format = size.toString().replaceAll('ImageFormats.', '');
        sources[format] = PhotoSource(src[format]);
      });

      return PexelsPhoto(
          photoData['id'],
          photoData['width'],
          photoData['height'],
          photoData['url'],
          photoData['photographer'],
          photoData['photographer_url'],
          sources);
    }
    return null;
  }

  /// [id] the id of the photo to return.
  /// if [id] is not specified, a random photo will be returned.
  Future<PexelsPhoto?> getPhoto({int? id}) async =>
      id == null ? _getPhotoRandom() : _getPhotoFromID(id);

  Future<SearchResult<PexelsPhoto?>?> searchPhotos(String query,
      {PexelsCollection collection = PexelsCollection.Regular,
      int resultsPerPage = 15,
      int page = 1,
      PexelsPhotoOrientation? orientation}) async {
    var url =
        _getPhotoEndpoint(collection, query, page, resultsPerPage, orientation);

    String? data = await _getData(url);

    if (data == null) return null;

    var resultData = jsonDecode(data);

    var photosData = resultData['photos'];

    if (photosData == null) return null;

    var photos = <PexelsPhoto?>[];

    for (dynamic photoData in photosData) {
      photos.add(_buildPhoto(photoData));
    }
    return new SearchResult(resultData['page'], resultData['per_page'],
        resultData['total_results'], resultData['next_page'], photos);
  }

  String _getPhotoEndpoint(
    PexelsCollection collection,
    String query,
    int page,
    int resultsPerPage,
    PexelsPhotoOrientation? orientation,
  ) {
    switch (collection) {
      case PexelsCollection.Curated:
        return Endpoints.photoSearchCurated(
          page: page,
          perPage: resultsPerPage,
          orientation: orientation,
        );
      case PexelsCollection.Popular:
        return Endpoints.photoSearchPopular(
          page: page,
          perPage: resultsPerPage,
          orientation: orientation,
        );
      case PexelsCollection.Regular: // fallback to default
      default:
        return Endpoints.photoSearch(
          query,
          page: page,
          perPage: resultsPerPage,
          orientation: orientation,
        );
    }
  }

  // Video

  String _getVideoEndpoint(
      PexelsCollection collection, int page, int resultsPerPage, String query) {
    switch (collection) {
      case PexelsCollection.Curated:
        return Endpoints.videoSearchCurated(
            page: page, perPage: resultsPerPage);
      case PexelsCollection.Popular:
        return Endpoints.videoSearchPopular(
            page: page, perPage: resultsPerPage);
      case PexelsCollection.Regular: // fallback to default
      default:
        return Endpoints.videoSearch(query,
            page: page, perPage: resultsPerPage);
    }
  }

  Future<PexelsVideo?> _getVideoRandom() async {
    var url = Endpoints.videoRandom();

    String? data = await _getData(url);

    if (data == null) return null;
    var o = jsonDecode(data);

    var videoData = o['videos'][0];

    return _buildVideo(videoData);
  }

  Future<PexelsVideo?> _getVideoFromID(int id) async {
    var url = Endpoints.video(id);

    String? data = await _getData(url);

    if (data == null) return null;
    var videoData = jsonDecode(data);

    return _buildVideo(videoData);
  }

  PexelsVideo? _buildVideo(videoData) {
    var videoFilesData = videoData['video_files'];

    if (videoFilesData != null) {
      var videoFiles = <VideoSource>[];

      for (var vf in videoFilesData) {
        var videoSource = new VideoSource(vf['id'], vf['width'], vf['height'],
            vf['quality'], vf['file_type'], vf['link']);

        videoFiles.add(videoSource);
      }

      return PexelsVideo(
          videoData['id'],
          videoData['width'],
          videoData['height'],
          videoData['url'],
          videoData['image'],
          videoData['full_res'],
          videoData['duration'],
          videoFiles);
    }

    return null;
  }

  Future<PexelsVideo?> getVideo({int? id}) async =>
      (id == null) ? _getVideoRandom() : _getVideoFromID(id);

  Future<SearchResult<PexelsVideo?>?> searchVideos(String query,
      {PexelsCollection collection = PexelsCollection.Regular,
      int resultsPerPage = 15,
      int page = 1,
      int? minWidth,
      int? maxWidth,
      int? minDuration,
      int? maxDuration}) async {
    var url = _getVideoEndpoint(collection, page, resultsPerPage, query);

    String? data = await _getData(url);

    if (data == null) return null;

    var resultData = jsonDecode(data);

    var videosData = resultData['videos'];

    if (videosData == null) return null;

    var videos = <PexelsVideo?>[];

    for (dynamic videoData in videosData) {
      videos.add(_buildVideo(videoData));
    }
    return new SearchResult(resultData['page'], resultData['per_page'],
        resultData['total_results'], resultData['next_page'], videos);
  }
}
