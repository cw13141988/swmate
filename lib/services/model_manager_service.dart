import '../common/constants/default_models.dart';
import '../common/llm_spec/cus_brief_llm_model.dart';
import '../common/llm_spec/cus_llm_spec.dart';
import '../common/utils/db_tools/db_helper.dart';

import 'cus_get_storage.dart';

class ModelManagerService {
  static final DBHelper _dbHelper = DBHelper();

  // 初始化内置模型
  static Future<void> initBuiltinModels() async {
    final models = defaultModels.map((model) {
      model.gmtCreate = DateTime.now();
      model.isBuiltin = true;
      return model;
    }).toList();

    for (final model in models) {
      final exists = await _dbHelper.queryCusBriefLLMSpecList(
        cusLlmSpecId: model.cusLlmSpecId,
      );

      if (exists.isEmpty) {
        await _dbHelper.insertCusBriefLLMSpecList([model]);
      }
    }
  }

  // 初始化内置模型(测试用,删除全部内置模型重新加入)
  static Future<void> initBuiltinModelsTest() async {
    final models = defaultModels.map((model) {
      model.gmtCreate = DateTime.now();
      model.isBuiltin = true;
      return model;
    }).toList();

    // 删除全部内置模型
    final exists = await _dbHelper.queryCusBriefLLMSpecList(isBuiltin: true);
    for (final model in exists) {
      await _dbHelper.deleteCusBriefLLMSpecById(model.cusLlmSpecId!);
    }

    await _dbHelper.insertCusBriefLLMSpecList(models);
  }

  // 获取可用的模型列表(有对应平台 AK 的模型)
  static Future<List<CusBriefLLMSpec>> getAvailableModels() async {
    final allModels = await _dbHelper.queryCusBriefLLMSpecList();
    final userKeys = MyGetStorage().getUserAKMap();

    return allModels.where((model) {
      if (model.cusLlmSpecId?.endsWith('_builtin') ?? false) {
        // 内置模型总是可用
        return true;
      }

      // 检查用户是否配置了该平台的 AK
      switch (model.platform) {
        case ApiPlatform.baidu:
          return userKeys['USER_BAIDU_API_KEY_V2']?.isNotEmpty ?? false;
        case ApiPlatform.siliconCloud:
          return userKeys['USER_SILICON_CLOUD_AK']?.isNotEmpty ?? false;
        case ApiPlatform.lingyiwanwu:
          return userKeys['USER_LINGYIWANWU_AK']?.isNotEmpty ?? false;
        case ApiPlatform.zhipu:
          return userKeys['USER_ZHIPU_AK']?.isNotEmpty ?? false;
        case ApiPlatform.infini:
          return userKeys['USER_INFINI_GEN_STUDIO_AK']?.isNotEmpty ?? false;
        case ApiPlatform.aliyun:
          return userKeys['USER_ALIYUN_API_KEY']?.isNotEmpty ?? false;
        case ApiPlatform.tencent:
          return userKeys['USER_TENCENT_API_KEY']?.isNotEmpty ?? false;
        default:
          return false;
      }
    }).toList();
  }

  // 指定模型分类来获取可用的模型列表
  static Future<List<CusBriefLLMSpec>> getAvailableModelByTypes(
    List<LLModelType> modelTypes,
  ) async {
    final allModels = await getAvailableModels();

    // 然后过滤出指定类型的模型
    List<CusBriefLLMSpec> list = allModels
        .where((model) => modelTypes.contains(model.modelType))
        .toList();

    // 固定平台排序后模型名排序
    list.sort((a, b) {
      // 先比较 平台名称
      int compareA = a.platform.name.compareTo(b.platform.name);
      if (compareA != 0) {
        return compareA;
      }

      // 如果 平台名称 相同，再比较 模型名称
      return a.name.compareTo(b.name);
    });

    return list;
  }

  // 验证用户导入的模型配置
  static bool validateModelConfig(Map<String, dynamic> json) {
    try {
      // 验证平台是否支持（这里找不到就会报错，在catch中会返回false）
      ApiPlatform.values.firstWhere(
        (e) => e.name == json['platform'],
        orElse: () => throw Exception('不支持的云平台'),
      );

      // 验证必填字段
      if (json['model'] == null ||
          json['modelType'] == null ||
          json['name'] == null ||
          json['isFree'] == null) {
        return false;
      }

      // 验证价格字段
      if (json['isFree'] == false) {
        if ((json['inputPrice'] == null &&
            json['outputPrice'] == null &&
            json['costPer'] == null)) {
          return false;
        }
      }

      return true;
    } catch (e) {
      rethrow;
    }
  }

  // 删除用户导入的模型(内置模型不能删除)
  static Future<bool> deleteUserModel(String modelId) async {
    if (modelId.endsWith('_builtin')) return false;

    await _dbHelper.deleteCusBriefLLMSpecById(modelId);
    return true;
  }

  // 清空用户导入的模型(保留内置模型)
  static Future<void> clearUserModels() async {
    final models = await _dbHelper.queryCusBriefLLMSpecList();
    for (final model in models) {
      if (!model.cusLlmSpecId!.endsWith('_builtin')) {
        await _dbHelper.deleteCusBriefLLMSpecById(model.cusLlmSpecId!);
      }
    }
  }
}
