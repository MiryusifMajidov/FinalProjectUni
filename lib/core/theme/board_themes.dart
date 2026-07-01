import 'package:flutter/material.dart';
import 'app_colors.dart';

enum BoardTheme {
  brownWood,
  greenFelt,
  darkMarble,
  blueIce,
  creamPaper,
}

extension BoardThemeExt on BoardTheme {
  String get displayName {
    switch (this) {
      case BoardTheme.brownWood:
        return 'Brown Wood';
      case BoardTheme.greenFelt:
        return 'Green Felt';
      case BoardTheme.darkMarble:
        return 'Dark Marble';
      case BoardTheme.blueIce:
        return 'Blue Ice';
      case BoardTheme.creamPaper:
        return 'Cream Paper';
    }
  }

  Color get lightSquare {
    switch (this) {
      case BoardTheme.brownWood:
        return AppColors.boardBrown1;
      case BoardTheme.greenFelt:
        return AppColors.boardGreen1;
      case BoardTheme.darkMarble:
        return AppColors.boardMarble1;
      case BoardTheme.blueIce:
        return AppColors.boardBlue1;
      case BoardTheme.creamPaper:
        return AppColors.boardCream1;
    }
  }

  Color get darkSquare {
    switch (this) {
      case BoardTheme.brownWood:
        return AppColors.boardBrown2;
      case BoardTheme.greenFelt:
        return AppColors.boardGreen2;
      case BoardTheme.darkMarble:
        return AppColors.boardMarble2;
      case BoardTheme.blueIce:
        return AppColors.boardBlue2;
      case BoardTheme.creamPaper:
        return AppColors.boardCream2;
    }
  }
}

enum PieceSet { cburnett, merida, alpha }

extension PieceSetExt on PieceSet {
  String get displayName => switch (this) {
        PieceSet.cburnett => 'CBurnett',
        PieceSet.merida => 'Merida',
        PieceSet.alpha => 'Alpha',
      };

  /// Asset folder name under assets/pieces/
  String get folderName => name;
}
