import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/src/tree/image_element.dart';

class ImageBuiltIn extends HtmlExtension {
  final String? dataEncoding;
  final Set<String>? mimeTypes;
  final Map<String, String>? networkHeaders;
  final Set<String> networkSchemas;
  final Set<String>? networkDomains;
  final Set<String>? fileExtensions;

  final String assetSchema;
  final AssetBundle? assetBundle;
  final String? assetPackage;

  final bool handleNetworkImages;
  final bool handleAssetImages;
  final bool handleDataImages;
  final ImageStreamListener? imageStreamListener;

  const ImageBuiltIn({
    this.networkHeaders,
    this.networkDomains,
    this.networkSchemas = const {"http", "https"},
    this.fileExtensions,
    this.assetSchema = "asset:",
    this.assetBundle,
    this.assetPackage,
    this.mimeTypes,
    this.dataEncoding,
    this.handleNetworkImages = true,
    this.handleAssetImages = true,
    this.handleDataImages = true,
    this.imageStreamListener,
  });

  @override
  Set<String> get supportedTags => {
    "img",
  };

  @override
  bool matches(ExtensionContext context) {
    if (context.elementName != "img") {
      return false;
    }

    return (_matchesNetworkImage(context) && handleNetworkImages) ||
        (_matchesAssetImage(context) && handleAssetImages) ||
        (_matchesBase64Image(context) && handleDataImages);
  }

  @override
  StyledElement prepare(ExtensionContext context, List<StyledElement> children) {
    final parsedWidth = double.tryParse(context.attributes["width"] ?? "");
    final parsedHeight = double.tryParse(context.attributes["height"] ?? "");

    return ImageElement(
      name: context.elementName,
      children: children,
      style: Style(),
      node: context.node,
      elementId: context.id,
      src: context.attributes["src"]!,
      alt: context.attributes["alt"],
      width: parsedWidth != null ? Width(parsedWidth) : null,
      height: parsedHeight != null ? Height(parsedHeight) : null,
    );
  }

  @override
  InlineSpan build(ExtensionContext context) {
    final element = context.styledElement as ImageElement;

    final imageStyle = Style(
      width: element.width,
      height: element.height,
    ).merge(context.styledElement!.style);

    late Widget child;
    if (_matchesBase64Image(context)) {
      child = _base64ImageRender(context, imageStyle);
    } else if (_matchesAssetImage(context)) {
      child = _assetImageRender(context, imageStyle);
    } else if (_matchesNetworkImage(context)) {
      child = _networkImageRender(context, imageStyle);
    } else {
      // Our matcher went a little overboard and matched
      // something we can't render
      return TextSpan(text: element.alt);
    }

    return WidgetSpan(
      //TODO: 去掉alignment by 刘志强
      // alignment: context.style!.verticalAlign
      //     .toPlaceholderAlignment(context.style!.display),
      alignment: PlaceholderAlignment.middle,
      baseline: TextBaseline.alphabetic,
      child: CssBoxWidget(
        style: imageStyle,
        childIsReplaced: true,
        child: child,
      ),
    );
  }

  static RegExp get dataUriFormat =>
      RegExp(r"^(?<scheme>data):(?<mime>image/[\w+\-.]+);*(?<encoding>base64)?,\s*(?<data>.*)");

  bool _matchesBase64Image(ExtensionContext context) {
    final attributes = context.attributes;

    if (attributes['src'] == null) {
      return false;
    }

    final dataUri = dataUriFormat.firstMatch(attributes['src']!);

    return context.elementName == "img" &&
        dataUri != null &&
        (mimeTypes == null || mimeTypes!.contains(dataUri.namedGroup('mime'))) &&
        dataUri.namedGroup('mime') != 'image/svg+xml' &&
        (dataEncoding == null || dataUri.namedGroup('encoding') == dataEncoding);
  }

  bool _matchesAssetImage(ExtensionContext context) {
    final attributes = context.attributes;

    return context.elementName == "img" &&
        attributes['src'] != null &&
        !attributes['src']!.endsWith(".svg") &&
        attributes['src']!.startsWith(assetSchema) &&
        (fileExtensions == null || attributes['src']!.endsWithAnyFileExtension(fileExtensions!));
  }

  bool _matchesNetworkImage(ExtensionContext context) {
    final attributes = context.attributes;

    if (attributes['src'] == null) {
      return false;
    }

    final src = Uri.tryParse(attributes['src']!);
    if (src == null) {
      return false;
    }

    return context.elementName == "img" &&
        networkSchemas.contains(src.scheme) &&
        !src.path.endsWith(".svg") &&
        (networkDomains == null || networkDomains!.contains(src.host)) &&
        (fileExtensions == null || src.path.endsWithAnyFileExtension(fileExtensions!));
  }

  Widget _base64ImageRender(ExtensionContext context, Style imageStyle) {
    final element = context.styledElement as ImageElement;
    final decodedImage = base64.decode(element.src.split("base64,")[1].trim());

    Image imageMemory = Image.memory(
      decodedImage,
      width: imageStyle.width?.value,
      height: imageStyle.height?.value,
      fit: BoxFit.fill,
      errorBuilder: (ctx, error, stackTrace) {
        return Text(
          element.alt ?? "",
          style: context.styledElement!.style.generateTextStyle(),
        );
      },
    );
    if (imageStreamListener != null) {
      ImageProvider provider = imageMemory.image;
      provider.resolve(ImageConfiguration.empty).addListener(imageStreamListener!);
    }

    return imageMemory;
  }

  Widget _assetImageRender(ExtensionContext context, Style imageStyle) {
    final element = context.styledElement as ImageElement;
    final assetPath = element.src.replaceFirst('asset:', '');

    Image image = Image.asset(
      assetPath,
      width: imageStyle.width?.value,
      height: imageStyle.height?.value,
      fit: BoxFit.fill,
      bundle: assetBundle,
      package: assetPackage,
      errorBuilder: (ctx, error, stackTrace) {
        return Text(
          element.alt ?? "",
          style: context.styledElement!.style.generateTextStyle(),
        );
      },
    );
    if (imageStreamListener != null) {
      ImageProvider provider = image.image;
      provider.resolve(ImageConfiguration.empty).addListener(imageStreamListener!);
    }
    return image;
  }

  Widget _networkImageRender(ExtensionContext context, Style imageStyle) {
    final element = context.styledElement as ImageElement;
    // 获取设备的像素密度（devicePixelRatio）
    BuildContext? ctx = context.buildContext;
    bool hasCtx = ctx != null;
    double? pixelRatio = (hasCtx ? MediaQuery.of(context.buildContext!).devicePixelRatio : 3.0) - 0.7;

    // 获取屏幕的逻辑宽度和高度（单位是逻辑像素）
    double screenWidth = hasCtx ? MediaQuery.of(context.buildContext!).size.width : 375;
    CachedNetworkImage image = CachedNetworkImage(
      imageUrl: element.src,
      width: imageStyle.width?.value,
      height: imageStyle.height?.value,
      memCacheWidth: imageStyle.width?.value != null ? (imageStyle.width!.value * pixelRatio).toInt() : null,
      memCacheHeight: imageStyle.height?.value != null ? (imageStyle.width!.value * pixelRatio).toInt() : null,
      imageBuilder: (context, imageProvider) {
        if (imageStreamListener != null) {
          imageProvider.resolve(ImageConfiguration.empty).addListener(imageStreamListener!);
        }
        Image imageView = Image(
          image: ResizeImage.resizeIfNeeded((screenWidth * pixelRatio).toInt(), null, imageProvider),
        );
        return imageView;
      },
      errorListener: (error) {
        imageStreamListener?.onError?.call(error, null);
      },
      fit: BoxFit.fill,
      errorWidget: (ctx, error, stackTrace) {
        return Text(
          element.alt ?? "",
          style: context.styledElement!.style.generateTextStyle(),
        );
      },
    );
    return CssBoxWidget(
      style: imageStyle,
      childIsReplaced: true,
      child: image,
    );
  }
}

extension _SetFolding on String {
  bool endsWithAnyFileExtension(Iterable<String> endings) {
    for (final element in endings) {
      if (endsWith(".$element")) {
        return true;
      }
    }
    return false;
  }
}
