// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_analysis.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FoodAnalysisAdapter extends TypeAdapter<FoodAnalysis> {
  @override
  final int typeId = 4;

  @override
  FoodAnalysis read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FoodAnalysis(
      query: fields[0] as String,
      foodName: fields[1] as String,
      jsonData: fields[2] as String,
      createdAt: fields[3] as DateTime,
      language: fields[4] as String,
      imagePath: fields[5] as String?,
      imageUrl: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FoodAnalysis obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.query)
      ..writeByte(1)
      ..write(obj.foodName)
      ..writeByte(2)
      ..write(obj.jsonData)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.language)
      ..writeByte(5)
      ..write(obj.imagePath)
      ..writeByte(6)
      ..write(obj.imageUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodAnalysisAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
