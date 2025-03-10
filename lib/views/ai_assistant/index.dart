import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../apis/_default_model_list/index.dart';
import '../../apis/_default_system_role_list/default_file_interpret_role_list.dart';
import '../../common/components/tool_widget.dart';
import '../../common/llm_spec/cus_llm_model.dart';
import '../../common/llm_spec/cus_llm_spec.dart';
import '../../common/utils/db_tools/db_ai_tool_helper.dart';
import '../../services/cus_get_storage.dart';
import '_componets/custom_entrance_card.dart';
import '_helper/tools.dart';
import 'ai_tools/chat_bot/index.dart';
import 'ai_tools/chat_bot_group/index.dart';
import 'ai_tools/file_interpret/document_interpret.dart';
import 'ai_tools/file_interpret/image_interpret.dart';
import 'ai_tools/image_generation/iti_index.dart';
import 'ai_tools/image_generation/tti_index.dart';
import 'ai_tools/image_generation/word_art_index.dart';
import 'ai_tools/video_generation/cogvideox_index.dart';
import 'config_llm_list/index.dart';
import 'config_system_prompt/index.dart';

///
/// 规划一系列有AI加成的使用工具，这里是主入口
/// 可使用tab或者其他方式分类为：对话、图生文、文生图/图生图等
///
class AIToolIndex extends StatefulWidget {
  const AIToolIndex({super.key});

  @override
  State createState() => _AIToolIndexState();
}

class _AIToolIndexState extends State<AIToolIndex> {
  final DBAIToolHelper dbHelper = DBAIToolHelper();

  // 默认的页面主体的缩放比例(对话太小了就可以等比放大)
  // 直接全局缓存，所有使用ChatListArea的地方都改了
  double _textScaleFactor = 1.0;

  // db中是否存在模型列表，不存在则自动导入免费的模型列表，已存在则忽略
  List cusModelList = [];

  @override
  void initState() {
    initModelAndSysRole();

    super.initState();

    // 获取缓存中的正文文本缩放比例
    _textScaleFactor = MyGetStorage().getChatListAreaScale();
  }

  // 初始化模型和系统角色信息到数据库
  // 后续文件还是别的东西看情况放
  initModelAndSysRole() async {
    // 如果数据库中已经有模型信息了，就不用再导入了
    var ll = await dbHelper.queryCusLLMSpecList();
    if (ll.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        cusModelList = ll;
      });
      return;
    }

    // 初始化模型信息和系统角色
    // 要考虑万一用户导入收费模型使用，顶不顶得住
    await testInitModelAndSysRole(FREE_all_MODELS);

    var afterList = await dbHelper.queryCusLLMSpecList();

    setState(() {
      cusModelList = afterList;
    });
  }

  // 调整对话列表中显示的文本大小
  void _adjustTextScale() async {
    var tempScaleFactor = _textScaleFactor;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '调整对话列表中文字大小',
            style: TextStyle(fontSize: 18.sp),
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: tempScaleFactor,
                    min: 0.6,
                    max: 2.0,
                    divisions: 14,
                    label: tempScaleFactor.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        tempScaleFactor = value;
                      });
                    },
                  ),
                  Text(
                    '当前文字比例: ${tempScaleFactor.toStringAsFixed(1)}',
                    textScaler: TextScaler.linear(tempScaleFactor),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('确定'),
              onPressed: () async {
                // 点击确定时，才把缩放比例存入缓存，并更新当前比例值
                setState(() {
                  _textScaleFactor = tempScaleFactor;
                });
                await MyGetStorage().setChatListAreaScale(
                  _textScaleFactor,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 计算屏幕剩余的高度
    // 设备屏幕的总高度
    //  - 屏幕顶部的安全区域高度，即状态栏的高度
    //  - 屏幕底部的安全区域高度，即导航栏的高度或者虚拟按键的高度
    //  - 应用程序顶部的工具栏（如 AppBar）的高度
    //  - 应用程序底部的导航栏的高度
    //  - 组件的边框间隔(不一定就是2)
    double screenBodyHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom -
        kToolbarHeight -
        kBottomNavigationBarHeight;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('AI 智能助手'),
        actions: [
          IconButton(
            onPressed: () async {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SystemPromptIndex(),
                ),
              );
            },
            icon: const Icon(Icons.face),
          ),
          IconButton(
            onPressed: () async {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ModelListIndex(),
                ),
              );
            },
            icon: const Icon(Icons.list_alt),
          ),
          IconButton(
            onPressed: _adjustTextScale,
            icon: const Icon(Icons.format_size_outlined),
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// 免责说明
          Text(
            "服务生成的所有内容均由人工智能模型生成，无法确保内容的真实性、准确性和完整性，仅供参考，且不代表开发者的态度或观点。",
            style: TextStyle(fontSize: 12.sp, color: Colors.grey),
          ),
          SizedBox(height: 10.sp),

          /// 入口按钮
          if (cusModelList.isNotEmpty)
            SizedBox(
              height: screenBodyHeight - 50.sp,
              child: GridView.count(
                primary: false,
                padding: EdgeInsets.symmetric(horizontal: 5.sp),
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
                crossAxisCount: 2,
                childAspectRatio: 3 / 2,
                children: <Widget>[
                  CustomEntranceCard(
                    title: '智能对话',
                    subtitle: "多个平台多种模型",
                    icon: Icons.chat_outlined,
                    onTap: () async {
                      await navigateToToolScreen(
                        context,
                        LLModelType.cc,
                        (llmSpecList, cusSysRoleSpecs) => ChatBot(
                          llmSpecList: llmSpecList,
                          cusSysRoleSpecs: cusSysRoleSpecs,
                        ),
                        roleType: LLModelType.cc,
                      );
                    },
                  ),

                  CustomEntranceCard(
                    title: '智能多聊',
                    subtitle: "一个问题多模型回答",
                    icon: Icons.balance_outlined,
                    onTap: () async {
                      await navigateToToolScreen(
                        context,
                        LLModelType.cc,
                        (llmSpecList, cusSysRoleSpecs) => const ChatBotGroup(),
                        roleType: LLModelType.cc,
                      );
                    },
                  ),

                  // 文档解读和图片解读不传系统角色类型
                  CustomEntranceCard(
                    title: '文档解读',
                    subtitle: "文档翻译总结提问",
                    icon: Icons.newspaper_outlined,
                    onTap: () async {
                      await navigateToToolScreen(
                        context,
                        LLModelType.cc,
                        (llmSpecList, cusSysRoleSpecs) => DocumentInterpret(
                          llmSpecList: llmSpecList,
                          cusSysRoleSpecs: cusSysRoleSpecs,
                        ),
                        isDocInterpret: true,
                      );
                    },
                  ),

                  CustomEntranceCard(
                    title: '图片解读',
                    subtitle: "图片翻译总结问答",
                    icon: Icons.image_outlined,
                    onTap: () async {
                      await navigateToToolScreen(
                        context,
                        LLModelType.vision,
                        (llmSpecList, cusSysRoleSpecs) => ImageInterpret(
                          llmSpecList: llmSpecList,
                          cusSysRoleSpecs: cusSysRoleSpecs,
                        ),
                        isImageInterpret: true,
                      );
                    },
                  ),

                  CustomEntranceCard(
                    title: '文本生图',
                    subtitle: "根据文字描述绘图",
                    icon: Icons.photo_album_outlined,
                    onTap: () async {
                      await navigateToToolScreen(
                        context,
                        LLModelType.tti,
                        (llmSpecList, cusSysRoleSpecs) => CommonTTIScreen(
                          llmSpecList: llmSpecList,
                          cusSysRoleSpecs: cusSysRoleSpecs,
                        ),
                        roleType: LLModelType.tti,
                      );
                    },
                  ),

                  CustomEntranceCard(
                    title: '创意文字',
                    subtitle: "纹理变形姓氏创作",
                    icon: Icons.text_fields_outlined,
                    onTap: () async {
                      await navigateToToolScreen(
                        context,
                        LLModelType.tti_word,
                        (llmSpecList, cusSysRoleSpecs) => AliyunWordArtScreen(
                          llmSpecList: llmSpecList,
                          cusSysRoleSpecs: cusSysRoleSpecs,
                        ),
                        roleType: LLModelType.tti_word,
                      );
                    },
                  ),

                  CustomEntranceCard(
                    title: '图片生图',
                    subtitle: "结合参考图片绘图",
                    icon: Icons.photo_library_outlined,
                    onTap: () async {
                      await navigateToToolScreen(
                        context,
                        LLModelType.iti,
                        (llmSpecList, cusSysRoleSpecs) => CommonITIScreen(
                          llmSpecList: llmSpecList,
                          cusSysRoleSpecs: cusSysRoleSpecs,
                        ),
                        roleType: LLModelType.iti,
                      );
                    },
                  ),

                  CustomEntranceCard(
                    title: '文生视频',
                    subtitle: "文本或图生成视频",
                    icon: Icons.video_call,
                    onTap: () async {
                      await navigateToToolScreen(
                        context,
                        LLModelType.ttv,
                        (llmSpecList, cusSysRoleSpecs) => CogVideoXScreen(
                          llmSpecList: llmSpecList,
                          cusSysRoleSpecs: cusSysRoleSpecs,
                        ),
                        roleType: LLModelType.ttv,
                      );
                    },
                  ),

                  // buildToolEntrance(
                  //   "[测试]",
                  //   icon: const Icon(Icons.chat_outlined),
                  //   color: Colors.blue[100],
                  //   onTap: () async {},
                  // ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

///
/// 点击智能助手的入口，跳转到子页面
///
Future<void> navigateToToolScreen(
  BuildContext context,
  LLModelType modelType,
  Widget Function(List<CusLLMSpec>, List<CusSysRoleSpec>) pageBuilder, {
  LLModelType? roleType,
  // 文档解读和图片解读就只用内部预设的角色列表(翻译、总结、分析)，不用用户自己的
  // 调用时，这两个不能同时存在
  bool? isDocInterpret,
  bool? isImageInterpret,
}) async {
  // 获取对话的模型列表(具体逻辑看函数内部)
  List<CusLLMSpec> llmSpecList = await fetchCusLLMSpecList(modelType);

  // 获取系统角色列表
  List<CusSysRoleSpec> cusSysRoleSpecs =
      await fetchCusSysRoleSpecList(roleType);

  if (isImageInterpret == true && isDocInterpret == true) {
    throw Exception("文档解读和图片解读不能同时指定");
  }

  // 如果是文档解读和图片解读，只用预设的翻译、总结、分析就好了，不要用户自定义
  if (isDocInterpret == true) {
    cusSysRoleSpecs = Doc_SysRole_List;
  }
  if (isImageInterpret == true) {
    cusSysRoleSpecs = Img_SysRole_List;
  }

  if (!context.mounted) return;
  if (llmSpecList.isEmpty) {
    return commonHintDialog(context, "提示", "无可用的模型，该功能不可用");
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => pageBuilder(llmSpecList, cusSysRoleSpecs),
      ),
    );
  }
}
