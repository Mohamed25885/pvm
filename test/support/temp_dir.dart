import 'dart:io';

// Test cleanup of temp dirs. Windows can briefly hold a just-written file
// (antivirus, indexer: "directory is not empty", errno 145), which made
// teardowns fail at random under full-suite load. A leftover temp dir is not
// a test failure.

Future<void> deleteTemp(Directory dir) async {
  try {
    if (await dir.exists()) await dir.delete(recursive: true);
  } on FileSystemException {
    // See above.
  }
}

void deleteTempSync(Directory dir) {
  try {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  } on FileSystemException {
    // See above.
  }
}
