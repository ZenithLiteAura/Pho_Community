//
//  Generated code. Do not modify.
//  source: proto/img_syncer.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class DirectoryType extends $pb.ProtobufEnum {
  static const DirectoryType DIRECTORY_TYPE_01 = DirectoryType._(0, _omitEnumNames ? '' : 'DIRECTORY_TYPE_01');
  static const DirectoryType DIRECTORY_TYPE_02 = DirectoryType._(1, _omitEnumNames ? '' : 'DIRECTORY_TYPE_02');

  static const $core.List<DirectoryType> values = <DirectoryType> [
    DIRECTORY_TYPE_01,
    DIRECTORY_TYPE_02,
  ];

  static final $core.Map<$core.int, DirectoryType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static DirectoryType? valueOf($core.int value) => _byValue[value];

  const DirectoryType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
