# 主菜单与设置UI

素材来自用户提供的羊皮纸叶纹UI_v2.zip，正式PNG按原样导入assets/ui/parchment/。main_background.png来自用户提供的主界面背景。主菜单按钮按360×60使用1:6长按钮；ESC卡片450×600保持3:4比例，内部按钮360×60。ESC整体采用1152×648设计尺寸等比适配，长内容可滚动。

音量滑条使用独立track/fill/thumb三张图片，按素材包提供的1200×120坐标规范绘制：填充原点100,44，填充满宽1000、高32，滑块中心100+1000×volume、60，滑块112×112；不把整张示意图作为控件。保留HSlider键盘操作，鼠标位置映射到轨道有效区间。

样式入口scripts/ui/parchment_theme.gd，滑条scripts/ui/parchment_slider.gd；主菜单scripts/ui/main_menu.gd，ESC界面scripts/ui/pause_menu.gd。原开始游戏、难度与种子、设置、音量、窗口大小、继续游戏、返回主界面、退出功能保留。
