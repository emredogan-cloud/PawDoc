// CloudFront viewer-request function: clean URLs -> S3 object keys.
//   /privacy        -> /privacy/index.html
//   /privacy/       -> /privacy/index.html
//   /               -> /index.html (also handled by default_root_object)
//   /styles/x.css   -> unchanged (has a dot)
function handler(event) {
  var request = event.request;
  var uri = request.uri;
  if (uri.endsWith("/")) {
    request.uri = uri + "index.html";
  } else if (uri.lastIndexOf(".") < uri.lastIndexOf("/")) {
    // no file extension after the last slash -> treat as a directory
    request.uri = uri + "/index.html";
  }
  return request;
}
