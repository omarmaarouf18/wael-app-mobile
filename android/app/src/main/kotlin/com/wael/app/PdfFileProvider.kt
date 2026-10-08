package com.wael.app

import androidx.core.content.FileProvider

// Own FileProvider subclass so its manifest entry cannot clash with a
// plugin's androidx FileProvider. Paths: res/xml/file_paths.xml.
class PdfFileProvider : FileProvider()
