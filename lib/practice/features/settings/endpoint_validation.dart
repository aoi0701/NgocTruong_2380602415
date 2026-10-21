import '../shared/api_endpoint.dart';

const defaultPostsEndpoint = 'https://jsonplaceholder.typicode.com/posts';

/// Validate the full collection URL, including the path supplied by the user.
String normalizePostsEndpoint(String value) {
  return collectionUri(value).toString();
}
