# 旅人动画资源说明

为了实现旅人动画效果，您需要准备以下图片资源：

## 必需的图片

1. `traveller_1.png`
2. `traveller_2.png` 
3. `traveller_3.png`
4. `traveller_4.png`

这些图片将用于在休息场景中，篝火右侧显示静坐的旅人动画。

## 图片要求

- 推荐尺寸：约400x400像素，或与其他角色动画帧相当
- 透明背景
- 动画帧设计：旅人坐在地上，微微活动（如呼吸、小幅度动作等）
- 头部朝向：原始图片中旅人头部朝右，但系统已配置为自动水平翻转，使其在游戏中头部朝左（面向篝火）

## 位置和显示

- 旅人将显示在篝火右侧，位置已在配置文件中设定
- 只有当用户购买并装备了"effect_5"特效时，旅人才会显示
- 动画配置在`animation_config.json`中的"traveller.sit"部分

## 开发注意事项

1. 旅人动画已配置为使用`flipped: true`，这会使图像在X轴上镜像翻转
2. 如需调整位置，请修改`animation_config.json`中`traveller.sit`的`offset`值
3. 如需调整大小，请修改`scale`值
4. 如需调整动画速度，请修改`fps`值

请将所有图片资源放在项目的Assets.xcassets目录中，确保命名与上述一致。 