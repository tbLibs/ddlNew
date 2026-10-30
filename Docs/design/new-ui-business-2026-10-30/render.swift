import AppKit

let out = CommandLine.arguments[1]
let W: CGFloat = 1776, H: CGFloat = 1040
func color(_ s: String) -> NSColor {
    let v = UInt32(s, radix: 16)!
    return NSColor(srgbRed: CGFloat((v >> 16) & 255)/255, green: CGFloat((v >> 8) & 255)/255, blue: CGFloat(v & 255)/255, alpha: 1)
}
let ink = color("182536"), secondary = color("647184"), green = color("2859BC"), pale = color("EAF0FA"), line = color("E4E9F0"), white = color("FFFFFF")
func rect(_ x: CGFloat,_ y: CGFloat,_ w: CGFloat,_ h: CGFloat,_ c: NSColor,_ radius: CGFloat = 0) {
    c.setFill(); NSBezierPath(roundedRect: NSRect(x:x,y:y,width:w,height:h),xRadius:radius,yRadius:radius).fill()
}
func text(_ s: String,_ x: CGFloat,_ y: CGFloat,_ size: CGFloat = 16,_ c: NSColor = ink,_ weight: NSFont.Weight = .regular,_ width: CGFloat = 350,_ align: NSTextAlignment = .left) {
    let p=NSMutableParagraphStyle(); p.alignment=align; p.lineBreakMode = .byTruncatingTail
    (s as NSString).draw(in:NSRect(x:x,y:y,width:width,height:size*1.7),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:c,.paragraphStyle:p])
}
func icon(_ name: String,_ x: CGFloat,_ y: CGFloat,_ size: CGFloat = 22,_ c: NSColor = ink) {
    guard let i=NSImage(systemSymbolName:name.replacingOccurrences(of:".fill",with:""),accessibilityDescription:nil)?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize:size,weight:.regular).applying(NSImage.SymbolConfiguration(paletteColors:[c]))) else {return}
    let ratio = i.size.width / max(i.size.height, 1)
    let w = ratio > 1 ? size : size * ratio, h = ratio > 1 ? size / ratio : size
    i.draw(in:NSRect(x:x+(size-w)/2,y:y+(size-h)/2,width:w,height:h),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
}
func divider(_ y: CGFloat,_ x: CGFloat = 20,_ w: CGFloat = 350) {rect(x,y,w,0.7,line)}
func avatar(_ initial: String,_ x: CGFloat,_ y: CGFloat,_ tone: Int = 0,_ size: CGFloat = 48) {
    let colors = ["E3EBE1","E9E2D6","E0E7E9","E8E1DA","E5E3EB"]
    rect(x,y,size,size,color(colors[tone % colors.count]),size/2)
    text(initial,x,y+(size-28)/2-1,21,color("46584D"),.medium,size,.center)
}
func arrow(_ y: CGFloat) {icon("chevron.right",350,y,13,secondary)}
func status() {
    text("9:41",25,16,14,ink,.semibold)
    icon("cellularbars",297,18,17); icon("wifi",320,18,17); icon("battery.100percent",344,16,23)
}
func tabs(_ selected: Int) {
    rect(0,760,390,84,white); divider(760,0,390)
    let names=["首页","消息","通讯录","我的"]
    let symbols=["house","bubble.left.and.bubble.right","person.crop.rectangle.stack","person.crop.circle"]
    for i in 0..<4 {
        let x = CGFloat(i)*97.5
        let c = i == selected ? green : secondary
        icon(symbols[i],x+37,774,23,c)
        if i == selected {rect(x+39,767,19,2,green,1)}
        text(names[i],x,802,11,c,i == selected ? .semibold : .regular,97.5,.center)
        if i == 1 {rect(x+59,772,7,7,color("BF5E45"),3.5)}
    }
    rect(135,833,120,4,ink,2)
}
func search(_ s: String,_ y: CGFloat = 120) {
    rect(20,y,350,42,color("F3F5F9"),10); icon("magnifyingglass",33,y+12,18,secondary); text(s,60,y+10,15,secondary)
}
func filters(_ items: [String],_ y: CGFloat = 180,_ selected:Int = 0) {
    for (i,s) in items.enumerated() {
        let x=CGFloat(i)*76+20
        text(s,x,y,15,i == selected ? green : secondary,i == selected ? .semibold : .regular,64)
    }
    rect(20+CGFloat(selected)*76,y+29,28,2.5,green,1)
    divider(y+37)
}
func title(_ s: String) {text(s,20,64,29,ink,.semibold)}
func menu(_ symbol: String,_ s: String,_ y: CGFloat,_ detail: String = "",_ div: Bool = true) {
    icon(symbol,22,y+16,21,green); text(s,57,y+14,16)
    if !detail.isEmpty {text(detail,204,y+17,13,secondary,.regular,132,.right)}
    arrow(y+21); if div {divider(y+53,57,313)}
}
struct Page: Decodable { let id,group,title,kind,action,source,note,variant,navMode,scene,state,after,role:String; let rows:[String]; let selected,locked:[Int]; let disabled,busy:Bool }
let dir=URL(fileURLWithPath:out)
let pages=try JSONDecoder().decode([Page].self,from:Data(contentsOf:dir.appendingPathComponent("pages.json")))
try FileManager.default.createDirectory(at:dir.appendingPathComponent("screens"),withIntermediateDirectories:true)
func paragraph(_ s:String,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ size:CGFloat=16,_ c:NSColor=ink) {
 let p=NSMutableParagraphStyle();p.lineSpacing=7;p.lineBreakMode = .byWordWrapping
 (s as NSString).draw(in:NSRect(x:x,y:y,width:w,height:150),withAttributes:[.font:NSFont.systemFont(ofSize:size),.foregroundColor:c,.paragraphStyle:p])
}
func nav(_ s:String,_ action:String="") {
 icon("chevron.left",20,65,20,green);text(s,56,63,17,ink,.semibold,278,.center)
 if !action.isEmpty {text(action,319,66,14,green,.medium,51,.right)}
 divider(107,0,390)
}
func primary(_ s:String,_ y:CGFloat=754,_ danger:Bool=false,_ disabled:Bool=false) {
 rect(20,y,350,50,disabled ? color("DCE2EB"):(danger ? color("B9413E"):green),12);text(s,26,y+13,16,disabled ? secondary:.white,.semibold,338,.center)
}
func row(_ s:String,_ y:CGFloat,_ picker:Bool=false,_ n:Int=0,_ selected:Bool=false,_ locked:Bool=false) {
 let parts=s.components(separatedBy:"|");let name=parts[0];let detail=parts.count>1 ? parts[1]:""
 let a:CGFloat=picker ? 61:20
 if picker {icon("circle",20,y+19,23,locked ? secondary:green);if selected || locked {icon("checkmark",25,y+24,13,green)}}
 if !detail.isEmpty {
  text(name,a,y+9,17,ink,.medium,290-a);text(detail,a,y+36,13,secondary,.regular,300-a)
 } else {text(name,a,y+20,17,ink,.regular,310-a)}
 if detail == "开启" || detail == "关闭" {
  rect(315,y+19,49,28,detail == "开启" ? green:color("D9DEE5"),14)
  rect(detail == "开启" ? 339:318,y+22,22,22,.white,11)
 } else if !picker && !detail.contains("只读") {arrow(y+25)}
 divider(y+70,a,370-a)
}
func chat(_ p:Page) {
 nav(p.variant == "single" ? "阿哲":"周六日落轻徒步（12）")
 icon("ellipsis",345,67,22,green)
 rect(0,108,390,630,color("F3F5F9"))
 if p.variant != "single" {rect(0,108,390,39,color("EAF0FA"));icon("megaphone",20,119,16,green);text("群公告：请提前10分钟到达集合点",48,118,12,green)}
 text("今天 14:32",0,167,11,secondary,.regular,390,.center)
 avatar("哲",16,205,0,38);text("阿哲",65,203,12,secondary)
 rect(65,226,270,91,.white,12);paragraph("明天16:30在北山游客中心集合，记得带好饮用水。",80,240,238,16)
 avatar("夏",337,343,1,38);rect(130,343,194,52,color("DCE7FD"),12);text("收到，我会提前到。",145,357,16)
 text("已读",285,402,11,secondary)
 avatar("哲",16,440,0,38);rect(65,440,152,49,.white,12);icon("waveform",80,453,23,green);text("18″",176,454,15)
 text("阿哲撤回了一条消息",0,518,11,secondary,.regular,390,.center)
 if p.variant == "attachments" {
  rect(0,600,390,244,.white); divider(600,0,390)
  for (i,t) in [("photo","照片"),("camera","拍摄"),("phone","语音通话"),("video","视频通话"),("folder","文件"),("person.crop.rectangle","名片"),("mappin","位置"),("face.smiling","表情")].enumerated() {
   let x=CGFloat(i%4)*90+15,y=CGFloat(i/4)*90+617
   icon(t.0,x+27,y,27,green);text(t.1,x,y+39,12,secondary,.regular,80,.center)
  }
 } else if p.variant == "recording" {
  rect(0,614,390,230,color("E4ECFA"));icon("waveform",171,647,48,green);text("00:08",0,706,18,green,.semibold,390,.center);text("松开发送，上滑取消",0,750,14,secondary,.regular,390,.center)
 } else if p.variant == "selection" {primary("转发选中消息",754);icon("checkmark.circle",23,324,24,green)}
 else {
  rect(0,738,390,106,.white);divider(738,0,390)
  if p.variant == "muted" {text("你当前已被禁言",20,767,15,secondary,.regular,350,.center)}
  else {icon("mic",16,758,24,green);rect(53,751,239,43,color("F0F3F8"),10);text("输入消息",66,762,16,secondary);icon("face.smiling",304,760,24,green);icon("plus.circle",347,760,24,green)}
 }
}
let bg = color("F3F5F9"), danger = color("B9413E")
func brandMark(_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ c:NSColor=green) {
 NSGraphicsContext.saveGraphicsState();let ctx=NSGraphicsContext.current!.cgContext
 ctx.translateBy(x:x,y:y);ctx.scaleBy(x:size/256,y:size/256)
 let p=NSBezierPath();p.windingRule = .evenOdd
 p.move(to:NSPoint(x:128,y:34))
 p.curve(to:NSPoint(x:224,y:121),controlPoint1:NSPoint(x:185,y:34),controlPoint2:NSPoint(x:224,y:71))
 p.curve(to:NSPoint(x:129,y:211),controlPoint1:NSPoint(x:224,y:174),controlPoint2:NSPoint(x:183,y:211))
 p.curve(to:NSPoint(x:86,y:202),controlPoint1:NSPoint(x:113,y:211),controlPoint2:NSPoint(x:99,y:208))
 p.line(to:NSPoint(x:43,y:223));p.line(to:NSPoint(x:51,y:180))
 p.curve(to:NSPoint(x:32,y:121),controlPoint1:NSPoint(x:38,y:165),controlPoint2:NSPoint(x:32,y:144))
 p.curve(to:NSPoint(x:128,y:34),controlPoint1:NSPoint(x:32,y:71),controlPoint2:NSPoint(x:72,y:34));p.close()
 p.move(to:NSPoint(x:76,y:120))
 p.curve(to:NSPoint(x:128,y:170),controlPoint1:NSPoint(x:80,y:151),controlPoint2:NSPoint(x:101,y:170))
 p.curve(to:NSPoint(x:181,y:120),controlPoint1:NSPoint(x:156,y:170),controlPoint2:NSPoint(x:177,y:151))
 p.line(to:NSPoint(x:158,y:120))
 p.curve(to:NSPoint(x:128,y:148),controlPoint1:NSPoint(x:154,y:138),controlPoint2:NSPoint(x:144,y:148))
 p.curve(to:NSPoint(x:99,y:120),controlPoint1:NSPoint(x:112,y:148),controlPoint2:NSPoint(x:102,y:138));p.close()
 c.setFill();p.fill();NSGraphicsContext.restoreGraphicsState()
}
func brandWordmark(_ x:CGFloat,_ y:CGFloat,_ size:CGFloat=29,_ c:NSColor=ink,_ width:CGFloat=350){
 let p=NSMutableParagraphStyle();p.alignment = .center
 ("叮咚聊" as NSString).draw(in:NSRect(x:x,y:y,width:width,height:size*1.6),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.semibold),.foregroundColor:c,.kern:1.3,.paragraphStyle:p])
}
func waitingSpinner(_ x:CGFloat,_ y:CGFloat) {
 for i in 0..<8 {
  let angle=CGFloat(i)*CGFloat.pi/4-CGFloat.pi/2
  let path=NSBezierPath();path.lineWidth=2.1;path.lineCapStyle = .round
  path.move(to:NSPoint(x:x+cos(angle)*4.5,y:y+sin(angle)*4.5))
  path.line(to:NSPoint(x:x+cos(angle)*8.2,y:y+sin(angle)*8.2))
  secondary.withAlphaComponent(0.24+CGFloat(i)*0.1).setStroke();path.stroke()
 }
}
func startupScene(_ waiting:Bool=false) {
 rect(0,0,390,844,white)
 brandMark(125,285,128)
 brandWordmark(20,438,29)
 if waiting {waitingSpinner(195,672);text("正在打开…",20,699,14,secondary,.regular,350,.center)}
}

func businessNav(_ p:Page,_ label:String) {
 if p.navMode == "root" {text(label,20,65,23,ink,.semibold)}
 else {
  if p.navMode == "cancel" {text("取消",20,65,16,green)}
  else if p.navMode == "done" {text("完成",325,65,16,green)}
  else {icon("chevron.left",20,65,20,green)}
  text(label,65,63,17,ink,.semibold,260,.center)
 }
 divider(107,0,390)
}
func field(_ label:String,_ value:String,_ y:CGFloat,_ multiline:Bool=false,_ placeholder:Bool=false) {
 text(label,20,y,13,secondary,.medium)
 rect(20,y+27,350,multiline ? 116:52,bg,12)
 if multiline {paragraph(value,35,y+42,318,16,placeholder ? secondary:ink)}
 else {text(value,35,y+42,16,placeholder ? secondary:ink,.regular,302)}
}
func check(_ label:String,_ y:CGFloat,_ checked:Bool,_ width:CGFloat=310) {
 icon(checked ? "checkmark.circle.fill":"circle",20,y+1,21,green);paragraph(label,52,y,width,14,ink)
}
func toast(_ message:String,_ y:CGFloat=690) {
 rect(31,y,328,48,ink,12);text(message,43,y+13,14,white,.medium,304,.center)
}
func dialog(_ heading:String,_ body:String,_ yes:String,_ no:String="取消",_ destructive:Bool=false) {
 rect(0,0,390,844,NSColor.black.withAlphaComponent(0.25))
 rect(50,286,290,246,white,15)
 text(heading,66,309,18,ink,.semibold,258,.center)
 paragraph(body,74,349,242,14,secondary)
 divider(475,50,290);rect(195,475,0.7,57,line)
 text(no,57,492,16,green,.regular,131,.center);text(yes,201,492,16,destructive ? danger:green,.semibold,131,.center)
}
func plainRow(_ name:String,_ detail:String,_ y:CGFloat,_ action:String="",_ bad:Bool=false) {
 text(name,20,y+9,17,ink,.medium,action.isEmpty ? 335:242)
 if !detail.isEmpty{text(detail,20,y+36,13,secondary,.regular,340)}
 if !action.isEmpty {text(action,279,y+19,14,bad ? danger:green,.medium,91,.right)}
 divider(y+71)
}
func loginScene(_ p:Page) {
 brandMark(14,54,42);text("叮咚聊",67,68,23,ink,.semibold);text("更换俱乐部",288,74,14,green)
 text("欢迎回来",20,171,34,ink,.semibold)
 text("当前俱乐部：远山户外",20,222,16,secondary)
 let empty=p.variant == "empty",busy=p.variant == "busy"
 field("账号",empty ? "输入会员账号":"linxia_demo",292,false,empty)
 field("密码",empty ? "输入密码":"••••••••",395,false,empty);icon("eye.slash",331,439,20,secondary)
 check("记住密码",502,true)
 check("我已阅读并同意",557,busy);text("隐私政策",52,586,14,green);text("和",114,586,14,secondary);text("使用支持",138,586,14,green)
 primary(busy ? "正在登录…":"登录",650,false,empty || busy)
 text("注册账号",20,721,16,green,.medium,350,.center)
 if p.scene == "011" {rect(20,113,350,40,bg,10);text("连接失败",33,123,14,danger);text("重试连接",273,123,14,green)}
 if p.scene == "010" {dialog("同意协议后继续","请阅读隐私政策与使用支持。同意后将继续本次登录。","同意并继续")}
}
func chatScene(_ p:Page) {
 let single=p.scene == "030",muted=p.scene == "115"
 nav(single ? "阿哲":"周六日落轻徒步（12）");icon("ellipsis",344,67,22,green)
 rect(0,108,390,630,bg)
 if !single {rect(0,108,390,39,pale);icon("megaphone",20,120,16,green);text("群公告：请提前10分钟到达集合点",48,119,13,green)}
 text("今天 14:32",0,164,12,secondary,.regular,390,.center)
 avatar("哲",16,205,0,38)
 if !single {text("阿哲",65,203,12,secondary)}
 let by:CGFloat=single ? 205:226
 rect(65,by,270,91,white,12);paragraph("明天16:30在北山游客中心集合，记得带好饮用水。",80,by+14,238,16)
 avatar("夏",337,350,1,38);rect(130,350,194,52,color("DCE7FD"),12);text("收到，我会提前到。",145,364,16)
 if p.variant == "failed" {icon("exclamationmark.circle.fill",99,364,22,danger)}
 else {icon(single ? "checkmark.circle":"circle.lefthalf.filled",307,411,14,green)}
 avatar("哲",16,457,0,38);rect(65,457,152,49,white,12);icon("waveform",80,470,23,green);text("18″",176,471,15)
 if p.scene == "032" {
  rect(0,580,390,264,white);divider(580,0,390)
  icon("mic",16,598,24,green);rect(53,590,239,43,bg,10);icon("face.smiling",304,599,24,green);icon("plus.circle",347,599,24,green)
  let acts=[("photo","相册"),("camera","拍摄"),("folder","文件"),("video","视频通话"),("phone","语音通话")]
  for(i,a) in acts.enumerated(){let x=CGFloat(i%4)*91+14,y=CGFloat(i/4)*76+657;icon(a.0,x+28,y,25,green);text(a.1,x,y+34,13,secondary,.regular,82,.center)}
 } else if p.scene == "033" {
  let cancel=p.variant == "cancel";rect(0,596,390,248,cancel ? color("F9E8E6"):pale)
  icon(cancel ? "xmark":"waveform",168,633,54,cancel ? danger:green)
  text(cancel ? "松开取消":"松开发送",0,709,22,cancel ? danger:green,.semibold,390,.center)
  text(cancel ? "手指滑回，继续录音":"上滑取消",0,749,15,secondary,.regular,390,.center)
 } else if p.scene == "034" {
  rect(0,51,390,56,white);text("取消",20,66,16,green);text("已选 2 条",95,65,17,ink,.semibold,200,.center)
  icon("checkmark.circle.fill",21,317,22,green);icon("checkmark.circle.fill",21,416,22,green)
  rect(0,738,390,106,white);divider(738,0,390)
  for(i,a) in [("doc.on.doc","合并转发"),("arrowshape.turn.up.right","逐条转发"),("trash","删除")].enumerated(){let x=CGFloat(i)*130;icon(a.0,x+52,757,24,i==2 ? danger:green);text(a.1,x,789,13,i==2 ? danger:green,.medium,130,.center)}
 } else {
  rect(0,738,390,106,white);divider(738,0,390)
  icon("mic",16,758,24,muted ? secondary:green);rect(53,751,239,43,bg,10)
  text(muted ? "当前无法发送消息":"输入消息",66,762,15,secondary)
  icon("face.smiling",304,760,24,muted ? secondary:green);icon("plus.circle",347,760,24,green)
  if muted {toast("你当前已被禁言",655)}
 }
}
func complaintScene(_ p:Page) {
 nav("投诉与支持")
 let empty=p.variant.isEmpty, busy=p.variant == "busy"
 text("投诉原因",20,135,13,secondary,.medium);rect(20,163,350,52,bg,12);text("发布违法有害信息",35,178,16);icon("chevron.up.chevron.down",337,181,15,secondary)
 text("图片证据",20,242,13,secondary,.medium);text(empty ? "0 / 9 · 必填":"1 / 9",237,242,13,secondary,.regular,133,.right)
 if !empty {
  rect(20,274,84,84,pale,10);icon("photo",46,296,32,green);icon("xmark.circle.fill",89,266,22,ink)
  rect(116,274,84,84,bg,10);icon("plus",146,304,24,green)
 } else {rect(20,274,84,84,bg,10);icon("plus",50,304,24,green);text("添加图片",123,305,15,green)}
 field("投诉内容（选填）",empty ? "请描述遇到的问题":"该用户在群内发布了不当信息，相关截图已附上。",389,true,empty)
 text(empty ? "0 / 200":"22 / 200",285,540,12,secondary,.regular,85,.right)
 field("联系邮箱",empty ? "用于接收处理结果":"member@example.com",580,false,empty)
 if p.variant == "failed" {toast("提交失败，请稍后重试。",685)}
 primary(busy ? "正在提交…":"提交投诉",754,false,empty || busy)
}
func massScene(_ p:Page) {
 let resend=p.scene == "095",failure=p.variant == "failed",attach=p.variant == "attachment"
 nav(resend ? "再次群发":"新建群发","取消")
 text("接收对象",20,137,13,secondary,.medium)
 plainRow("阿哲、陈默",resend ? "2个对象 · 不可修改":"2个对象",161,resend ? "":"修改")
 field(resend ? "群发标签 · 不可修改":"群发标签（选填）","周末集合提醒",259)
 text("6 / 16",300,345,12,secondary,.regular,70,.right)
 text(attach ? "附件":"群发正文",20,396,13,secondary,.medium)
 if attach {rect(20,428,350,113,bg,12);icon("doc.text",36,453,40,green);text("活动路线.pdf",94,448,17,ink,.medium);text("PDF 文件",94,482,13,secondary);icon("xmark.circle",338,447,20,secondary);text("移除附件，改发文字",20,569,14,green)}
 else {rect(20,428,350,166,bg,12);paragraph("明天16:30在北山游客中心集合，请提前10分钟到达。",36,445,318,17);text("改发图片、视频或文件",20,621,14,green);text("选择附件后仅发送附件",20,653,13,secondary)}
 if failure {toast("提交失败，内容已保留，请重试。",685)}
 primary(resend ? "再发一次":"发送",754)
}
func contactScene(_ p:Page) {
 let stranger=p.variant == "stranger",blocked=p.variant == "blocked"
 nav("用户资料");if !stranger {icon("ellipsis",344,67,22,green)}
 avatar("哲",20,147,0,72);text("阿哲",115,151,27,ink,.semibold);text("账号：azhe_demo",115,192,14,secondary);icon("doc.on.doc",338,194,18,green)
 divider(252)
 if !stranger {row("备注|阿哲",275);row("描述|周末一起徒步的伙伴",360)}
 if blocked {paragraph("对方在黑名单中，暂时无法发起聊天。",20,483,350,15,secondary)}
 primary(stranger ? "添加好友":"发消息",754,false,blocked)
}
func businessScene(_ p:Page)->Bool {
 let id=p.scene
 if ["003","010","011"].contains(id) {loginScene(p);return true}
 if ["030","031","032","033","034","115"].contains(id) {chatScene(p);return true}
 if id == "103" {complaintScene(p);return true}
 if ["092","095"].contains(id) {massScene(p);return true}
 if id == "056" {contactScene(p);return true}
 switch id {
 case "001":startupScene(p.variant == "waiting");return true
 case "002":
  brandMark(14,54,42);text("叮咚聊",67,68,23,ink,.semibold)
  text("连接俱乐部",20,174,32,ink,.semibold);text("输入俱乐部提供的邀请码",20,225,16,secondary)
  field("俱乐部邀请码","请输入邀请码",309,false,true)
  primary("连接俱乐部",462,false,true)
  return true
 case "057","074","099":
  if id == "057" {contactScene(p)}
  else if id == "099" {nav("个人资料");text("头像",20,153,17);avatar("夏",299,133,1,54);divider(206);row("昵称|林夏",225);plainRow("账号","linxia_demo",318,"复制")}
  else {nav("群成员");for(i,a) in ["阿哲|群主","林野|管理员","陈默|群成员"].enumerated(){row(a,139+CGFloat(i)*78)}}
  rect(0,0,390,844,NSColor.black.withAlphaComponent(0.22))
  let actions=Array(p.rows.dropFirst()), h=CGFloat(actions.count)*52+138, y=844-h
  rect(0,y,390,h,white,20);rect(171,y+12,48,5,line,2.5)
  text(p.rows.first ?? p.title,20,y+32,15,secondary,.medium,350,.center)
  for(i,a) in actions.enumerated(){let yy=y+72+CGFloat(i)*52;text(a,20,yy,17,(a.contains("删除") || a.contains("移除") || a.contains("黑名单")) ? danger:green,.regular,350,.center);divider(yy+38)}
  text("取消",20,791,17,green,.semibold,350,.center)
  return true
 case "005":
  businessNav(p,p.variant == "secure" ? "安全码验证":"登录验证")
  if p.variant == "secure" {field("安全码","输入安全码",162,false,true)}
  else {
   rect(20,151,350,100,bg,12)
   if p.variant == "failed" {icon("exclamationmark.circle",177,182,32,danger)}else{text("7  A  3  K",20,177,32,green,.medium,350,.center)}
   field("图片验证码","输入图中字符",288,false,true)
   if p.variant == "failed" {paragraph("验证码图片加载失败，请取消后重新登录。",20,409,350,15,danger)}
  }
  primary("继续",754,false,true);return true
 case "006":
  businessNav(p,"登录验证");text("请完成安全验证",20,141,22,ink,.semibold)
  rect(20,199,350,340,bg,12)
  icon(p.variant == "failed" ? "wifi.exclamationmark":"arrow.triangle.2.circlepath",174,310,42,secondary)
  text(p.variant == "failed" ? "验证页面加载失败":"正在加载验证…",20,381,16,secondary,.regular,350,.center)
  if p.variant == "failed" {primary("重试验证",577)}
  return true
 case "028":
  title("消息");icon("magnifyingglass",295,72,23,green);icon("plus",343,72,23,green)
  search("搜索会话或消息预览",118);filters(["全部","未读"],181)
  let list=[("哲","周六日落轻徒步","阿哲：集合点已确认，周六见！","14:32"),("哲","阿哲","收到，周六见。","14:26"),("默","城市夜骑交流群","[草稿] 周五几点集合？","昨天"),("群","群发助手","查看最近的群发记录","昨天")]
  for(i,a) in list.enumerated(){let y:CGFloat=239+CGFloat(i)*99
   if i==0 {rect(0,y-9,390,94,bg)}
   avatar(a.0,20,y,i);text(a.1,84,y,17,ink,.medium,226);text(a.2,84,y+32,13,i==2 ? danger:secondary,.regular,270);text(a.3,309,y+3,11,secondary,.regular,61,.right)
   if i==0 {rect(51,y-7,22,22,danger,11);text("3",51,y-5,12,white,.semibold,22,.center);icon("pin.fill",345,y+36,12,secondary)}
   if i==1 {rect(58,y+37,9,9,green,5)}
   if i==2 {icon("bell.slash",347,y+59,14,secondary)}
   divider(y+82,84,286)
  }
  tabs(1);return true
 case "029":
  nav("全局搜索");search("北山",125)
  for(i,a) in [("好友","北山阿哲","账号：azhe_demo"),("群聊","北山徒步交流群","12位成员"),("单聊消息","阿哲","明天在北山游客中心集合。"),("群聊消息","周六日落轻徒步","阿哲：集合点在北山游客中心。")].enumerated(){let y:CGFloat=196+CGFloat(i)*136
   text(a.0,20,y,14,secondary,.medium);text("1",347,y,13,secondary);avatar(String(a.1.prefix(1)),20,y+35,i,44);text(a.1,80,y+36,17,ink,.medium,260);text(a.2,80,y+67,13,secondary,.regular,280);arrow(y+48);divider(y+112,80,290)
  };return true
 case "035":
  nav("阿哲");rect(0,108,390,736,bg);rect(113,222,240,60,color("DCE7FD"),12);text("收到，我会提前到。",130,241,17)
  rect(145,300,211,416,white,12)
  for(i,a) in ["复制","回复","转发","编辑","置顶","仅为我删除","双向删除","撤回"].enumerated(){text(a,165,315+CGFloat(i)*49,16,i>4 ? danger:ink);if i<7 {divider(352+CGFloat(i)*49,161,179)}}
  return true
 case "037":
  nav("选择@成员","取消");search("搜索成员",127)
  for(i,a) in ["阿哲|群主","陈默|群成员","林野|群成员"].enumerated(){row(a,198+CGFloat(i)*81)}
  return true
 case "043":
  nav("消息置顶");rect(20,146,350,99,bg,12);paragraph("明天16:30在北山游客中心集合。",36,166,318,17)
  plainRow("仅为我置顶","只出现在你的置顶列表",284,"置顶")
  plainRow("为所有人置顶","同步到群成员的置顶列表",382,"置顶")
  return true
 case "044":
  nav("表情");text("贴纸",20,137,16,green,.medium)
  for i in 0..<12 {icon(["heart","hand.thumbsup","sun.max","star"][i%4],CGFloat(i%4)*90+39,215+CGFloat(i/4)*111,42,green)}
  return true
 case "045","046","114":
  rect(0,0,390,844,color("101821"));icon("xmark",23,65,22,white)
  if id != "114" {icon("ellipsis",345,65,22,white)}
  rect(0,229,390,330,color("233B59"));icon(id == "046" ? "play.circle":id == "114" ? "photo.badge.exclamationmark":"photo",145,337,100,color("C2D3E9"))
  if id == "114" {text("原消息已失效",20,602,17,white,.medium,350,.center)}
  if id == "046" {text("00:18",20,755,13,white);rect(80,764,222,2,color("768493"));rect(80,764,47,2,white);icon("speaker.wave.2",341,752,21,white)}
  return true
 case "048":
  nav("语音详情");icon("waveform",159,210,72,green);text("语音 18 秒",20,321,24,ink,.semibold,350,.center);row("听筒播放|关闭",414);primary("播放");return true
 case "051":
  title("通讯录");icon("magnifyingglass",297,72,23,green);icon("person.badge.plus",340,72,24,green)
  search("搜索好友",118);filters(["好友","群聊","分组"],181)
  for(i,a) in ["新朋友|2条待处理","群助手|查看入群申请","文件助手|文件与笔记"].enumerated(){row(a,231+CGFloat(i)*71)}
  text("A",20,467,12,secondary);avatar("哲",20,496,0,44);text("阿哲",80,505,17,ink,.medium);rect(55,531,8,8,green,4);divider(557,80,267)
  text("C",20,581,12,secondary);avatar("默",20,610,1,44);text("陈默",80,619,17,ink,.medium);divider(671,80,267)
  text("2位好友",20,706,13,secondary)
  for(i,a) in ["A","C","D","L","M","Q","X","Z"].enumerated(){text(a,371,421+CGFloat(i)*23,10,green,.medium,12,.center)}
  tabs(2);return true
 case "054":
  nav("添加好友");field("账号","azhe_demo",141);primary("查找",255)
  divider(350);avatar("哲",20,382,0,48);text("阿哲",84,384,18,ink,.medium);text("账号：azhe_demo",84,416,14,secondary);arrow(401);return true
 case "055":
  nav("新朋友");search("搜索新朋友",125)
  plainRow("林野","通过账号搜索请求添加你",198,"通过验证")
  plainRow("阿哲","等待验证",288)
  plainRow("丁丁","已添加",378)
  plainRow("陈默","申请未通过",468,"重新申请")
  text("加载更多",20,594,14,green,.medium,350,.center);return true
 case "058":
  nav("备注与描述","保存");field("好友备注","阿哲",144);text("2 / 50",300,229,12,secondary,.regular,70,.right)
  field("描述","周末一起徒步的伙伴，下次一起走北山线。",283,true);text("19 / 200",280,434,12,secondary,.regular,90,.right)
  if p.variant == "failed" {toast("保存失败，修改内容已保留",552)}
  return true
 case "059":
  nav("分组管理","添加");for(i,a) in p.rows.enumerated(){let y:CGFloat=139+CGFloat(i)*84;plainRow(a.components(separatedBy:"|")[0],a.components(separatedBy:"|")[1],y);icon("ellipsis",304,y+20,20,green);icon("line.3.horizontal",347,y+20,20,secondary)};return true
 case "061":
  nav("移动分组");text("选择分组后立即移动",20,140,14,secondary)
  for(i,a) in ["户外伙伴","骑行伙伴","默认分组"].enumerated(){let y:CGFloat=190+CGFloat(i)*73;text(a,20,y+20,17);if i==0{icon("checkmark",341,y+23,18,green)};divider(y+69)}
  text("添加分组",20,451,17,green);return true
 case "066":
  nav("群聊设置");avatar("群",20,140,2,58);text("周六日落轻徒步",96,143,21,ink,.semibold,270);text("12位成员",96,177,14,secondary)
  row("查看群成员|12人",224)
  let member=p.variant == "member"
  let items=member ? ["群名称|周六日落轻徒步 · 只读","群二维码","群公告","查找聊天记录","置顶会话|开启","消息免打扰|关闭"]:["群名称|周六日落轻徒步","群二维码","群公告","群管理","查找聊天记录","置顶会话|开启"]
  for(i,a) in items.enumerated(){row(a,310+CGFloat(i)*70)}
  return true
 case "067","068","069","071","090","093","064":
  let t=id == "069" ? "邀请群成员":p.title
  businessNav(p,t);text(p.action,282,66,14,green,.medium,88,.right)
  search("搜索",125)
  var y:CGFloat=244
  if ["067","068","069"].contains(id) {filters(["全部","最近","分组"],183)}
  else if id == "093" {filters(["最近聊天","好友","群聊"],183)}
  else if id == "064" {filters(["好友","群聊"],183)}
  if id == "069" {field("邀请理由","一起参加本周末的徒步活动。",235,true);y=412}
  if id == "093" {text("查看已选（2）",20,238,14,green);text("全选当前",292,238,14,green);y=281}
  for(i,a) in p.rows.enumerated(){row(a,y+CGFloat(i)*79,true,i,p.selected.contains(i),p.locked.contains(i))}
  if ["067","068"].contains(id){divider(687);avatar("哲",20,709,0,40);avatar("默",72,709,1,40);text("已选择 2 人",131,721,14,secondary)}
  return true
 case "083":
  nav("群助手");filters(["全部","待审核"],135,p.variant == "pending" ? 1:0)
  let pending=p.variant == "pending"
  if pending {text("全选",20,199,15,green)}
  for(i,a) in [("林野","阿哲邀请林野加入","周六日落轻徒步"),("木木","木木申请加入","城市夜骑交流群")].enumerated(){let y:CGFloat=238+CGFloat(i)*169
   if pending {icon(i==0 ? "checkmark.circle.fill":"circle",20,y+2,23,green)}
   text(a.0,pending ? 58:20,y,19,ink,.semibold);text(a.1,20,y+39,15,secondary);text(a.2,20,y+67,13,secondary)
   if !pending {text("拒绝",230,y+108,15,danger);text("同意",319,y+108,15,green)}
   divider(y+148)
  }
  if pending {text("拒绝",40,770,17,danger);rect(145,754,225,50,green,12);text("同意（1）",145,768,16,white,.semibold,225,.center)}
  return true
 case "086","087","088","089":
  rect(0,0,390,844,color("142239"));text("9:41",25,16,14,white,.semibold);icon("chevron.down",20,65,23,white)
  let group=id == "089",video=id == "088",incoming=id == "086",waiting=p.variant == "waiting"
  text(group ? "周六日落轻徒步":"阿哲",20,127,26,white,.semibold,350,.center)
  text(incoming ? "邀请你语音通话":waiting ? "等待对方接听…":group ? "4人正在通话":"03:24",20,172,16,color("B4C3D8"),.regular,350,.center)
  if group {for(i,n) in ["阿哲","陈默","林夏","林野"].enumerated(){let x:CGFloat=20+CGFloat(i%2)*180,y:CGFloat=245+CGFloat(i/2)*157;rect(x,y,170,139,color("20344F"),12);avatar(String(n.suffix(1)),x+58,y+21,i,54);text(n,x,y+96,15,white,.regular,170,.center)}}
  else {avatar("哲",143,292,0,104)}
  if video {rect(282,222,87,125,color("20344F"),12);icon("video.slash",306,262,36,white);icon("arrow.triangle.2.circlepath.camera",334,563,27,white)}
  if incoming {for(i,a) in [("phone.down.fill","拒绝"),("phone.fill","接听")].enumerated(){let x:CGFloat=i==0 ? 55:235;rect(x,711,100,64,i==0 ? danger:green,32);icon(a.0,x+34,729,30,white);text(a.1,x,792,15,white,.medium,100,.center)}}
  else {let c=video ? [("mic.slash","静音"),("speaker.wave.2","扬声器"),("video","摄像头")]:[("mic.slash","静音"),("speaker.wave.2","扬声器")]
   for(i,a) in c.enumerated(){let x:CGFloat=CGFloat(i)*112+35;icon(a.0,x+25,638,28,white);text(a.1,x,680,14,white,.regular,82,.center)}
   primary(waiting ? "取消呼叫":"挂断",754,true)
  };return true
 case "091":
  nav("群发助手","新建")
  plainRow("周末集合提醒",p.variant == "accepted" ? "已受理 · 2个接收对象":"已受理 · 12个接收对象",140)
  paragraph("明天16:30在北山游客中心集合，请提前10分钟到达。",20,230,350,16)
  text("查看对象",20,306,14,green);text("再发一次",190,306,14,green);text("删除",330,306,14,danger);divider(350)
  plainRow("活动通知","12个接收对象 · 2个失败",381)
  text("活动路线.pdf",20,475,16);text("查看失败",20,529,14,green);text("再发一次",190,529,14,green);text("删除",330,529,14,danger)
  if p.variant == "accepted"{toast("已受理，可刷新查看发送结果",671)}
  return true
 case "094":
  nav("接收对象");filters(p.variant == "failed" ? ["失败（2）","全部（12）"]:["全部（12）","失败（2）"],139)
  if p.variant == "failed" {plainRow("陈默","对方拒绝接收",217);plainRow("木木","不在可发送范围",304)}
  else {for(i,a) in [("阿哲","好友"),("陈默","好友"),("周六日落轻徒步","群聊")].enumerated(){plainRow(a.0,a.1,217+CGFloat(i)*87)}}
  return true
 case "096","104":
  title("我的");icon("gearshape",341,72,23,green);avatar("夏",20,137,1,64);text("林夏",102,138,24,ink,.semibold);icon("pencil",175,147,18,secondary)
  text("账号：linxia_demo",102,177,13,secondary);icon("doc.on.doc",261,180,15,green);icon("qrcode",339,159,24,green)
  divider(229)
  for(i,a) in ["我的报名","候补记录","签到记录","已参加活动"].enumerated(){row(a,245+CGFloat(i)*60)}
  row("当前俱乐部|远山户外",500);row("更换俱乐部",574);row("黑名单",638);text("投诉与支持",20,729,16,green);tabs(3)
  if id == "104" {toast("投诉已提交",636)}
  return true
 case "097":
  nav("个人资料");text("头像",20,153,17);avatar("夏",299,133,1,54);arrow(153);divider(206)
  row("昵称|林夏",225);plainRow("账号","linxia_demo",318,"复制");return true
 case "098":
  nav("修改昵称");field("昵称","林夏",150);icon("xmark.circle.fill",337,193,18,secondary);text("2 / 30",300,240,13,secondary,.regular,70,.right);primary("保存",754,false,true);return true
 case "102","117","112":
  nav("黑名单")
  if id == "112" {icon("wifi.exclamationmark",166,260,58,secondary);text("暂时无法加载",20,355,22,ink,.semibold,350,.center);text("重试",20,417,17,green,.medium,350,.center)}
  else {plainRow("陈默","账号：chenmo_demo",145,id == "117" ? "移出中…":"移出");plainRow("木木","账号：mumu_demo",239,"移出")}
  return true
 case "105","106":
  nav("注销账号");text("注销前，请确认",20,151,27,ink,.semibold);paragraph("账号注销后将无法再次登录，账号相关记录将被清除。此操作不可撤销。",20,215,350,17)
  divider(335);paragraph("如果你只是暂时离开，可以选择退出登录。",20,371,350,16,secondary)
  check("我已了解注销后果",611,p.variant == "ready" || id == "106")
  primary("确认注销账号",754,true,p.variant != "ready" && id != "106")
  if id == "106" {dialog("确认注销账号？","注销后无法再次登录。此操作不可撤销。","注销账号","取消",true)}
  return true
 case "109","110":
  businessNav(p,p.title);icon("arrow.triangle.2.circlepath",175,331,40,secondary);text("正在加载…",20,394,16,secondary,.regular,350,.center);return true
 case "111":
  nav("全局搜索");search("没有匹配的关键词",125);icon("magnifyingglass",165,294,60,secondary);text("没有找到相关结果",20,392,22,ink,.semibold,350,.center);text("试试其他关键词",20,436,16,secondary,.regular,350,.center);return true
 case "013","018","019","020","021","121":
  nav(id == "121" ? "活动":p.title)
  var y:CGFloat=143
  if id == "013" || id == "121" {search("搜索活动",125);filters(["全部","可报名","已报名","已结束"],185);y=244}
  for(i,a) in p.rows.enumerated(){row(a,y+CGFloat(i)*94)}
  return true
 case "014":
  nav("活动详情");text("周六日落轻徒步",20,145,27,ink,.semibold);text("6公里轻徒步",20,191,15,secondary);divider(237)
  icon("calendar",20,266,21,green);text("10月16日 16:30",59,265,17)
  icon("mappin.and.ellipse",20,318,21,green);text("北山游客中心",59,317,17)
  plainRow("活动名额",p.variant == "waiting" ? "名额已满":"还有名额，可报名",383)
  text("参与须知",20,500,19,ink,.semibold);paragraph("请穿防滑运动鞋，携带饮用水。\n取消报名请至少提前12小时。",20,544,350,16,secondary)
  primary(p.variant == "joined" ? "前往签到":p.variant == "waiting" ? "加入候补":"报名参加",754)
  if p.variant == "joined" {text("取消报名",20,694,15,danger,.medium,350,.center)}
  return true
 case "023":
  nav("个人签到");text("城市夜骑 · 江畔线",20,151,25,ink,.semibold);text("签到时间 19:00–19:45",20,197,15,secondary)
  field("4位签到码",p.variant == "error" ? "1234":"输入签到码",280,false,p.variant != "error")
  if p.variant == "error" {text("签到码不正确，请确认后重试。",20,394,15,danger)}
  primary("确认签到",754,false,p.variant != "error");return true
 default:return false
 }
}

func drawPage(_ p:Page) {
 rect(0,0,390,844,white);status()
 if businessScene(p) {rect(135,833,120,4,p.kind == "call" || ["045","046","114"].contains(p.scene) ? .white:ink,2);return}
 let top=["home","inbox","contacts","mine"].contains(p.kind)
 if top {title(p.title)} else if p.kind != "call" && p.kind != "chat" && p.variant != "loading" {businessNav(p,p.title)}
 switch p.kind {
 case "home":
  text("远山户外俱乐部",20,114,14,secondary);icon("bell",340,71,24,green)
  divider(155);text("下一场活动",20,177,17,ink,.semibold)
  text("15",20,218,48,green,.medium,82);text("10月",22,279,12,secondary)
  text("城市夜骑",123,226,24,ink,.semibold);text("江畔线",123,262,19,ink,.medium)
  text("19:30 · 滨江广场",123,300,14,secondary);icon("checkmark.circle",123,333,15,green);text("已报名",145,330,13,green)
  primary("查看参与信息",378)
  for(i,s) in ["我的报名","候补记录","活动签到"].enumerated(){text(s,20+CGFloat(i)*117,457,14,green,.medium,117,.center)}
  divider(495);text("近期活动",20,516,19,ink,.semibold);text("全部",332,521,14,green)
  row("周六日落轻徒步|10月16日 16:30 · 北山森林公园",551)
  row("森林观鸟晨行|10月24日 06:30 · 东湖湿地入口",625)
  text("俱乐部介绍",20,725,14,green);text("公告",332,725,14,green);tabs(0)
 case "inbox":
  icon("plus",344,73,23,green);search("搜索好友、群聊和聊天内容",116)
  for(i,s) in p.rows.enumerated(){let y=CGFloat(i)*98+184;avatar(String(s.prefix(1)),20,y,i);let a=s.components(separatedBy:"|");text(a[0],84,y+1,17,ink,.medium,225);text(a[1],84,y+31,13,secondary,.regular,273);text(i==0 ? "14:32":"昨天",309,y+3,11,secondary,.regular,61,.right);divider(y+79,84,286)}
  tabs(1)
 case "contacts":
  icon("person.badge.plus",342,72,24,green);search("搜索好友和群聊",117);filters(["好友","群聊","分组"],177)
  for(i,s) in p.rows.enumerated(){row(s,232+CGFloat(i)*76)};tabs(2)
 case "mine":
  icon("gearshape",341,72,23,green);avatar("夏",20,137,1,64);text("林夏",102,138,24,ink,.semibold);text("账号：linxia_demo",102,177,13,secondary);icon("qrcode",339,159,24,green)
  divider(229)
  for(i,s) in ["我的报名","候补记录","签到记录","已参加活动"].enumerated(){row(s,247+CGFloat(i)*61)}
  row("当前俱乐部|远山户外",502);row("更换俱乐部",575);row("黑名单",639);text("投诉与支持",20,727,16,green);tabs(3)
 case "chat":chat(p)
 case "form":
  var y:CGFloat=142
  if p.title == "投诉与支持" {
   text("图片证据（必填）",20,137,14,ink,.medium);text("0/9",324,137,13,secondary)
   rect(20,171,76,76,pale,10);icon("plus",46,195,24,green);text("添加图片",114,197,14,green);y=273
  }
  if p.variant == "login" {text("远山",20,148,38,ink,.semibold);text("登录后，继续你的会员行程。",20,207,15,secondary);y=264}
  if p.variant == "captcha" {rect(20,143,350,90,pale,10);text("7  A  3  K",20,166,32,green,.medium,350,.center);y=255}
  for s in p.rows {
   if s.contains("|"){let a=s.components(separatedBy:"|");text(a[0],20,y,13,secondary,.medium);rect(20,y+28,350,52,color("F2F5FA"),10);text(a[1],35,y+43,16,a[1].contains("输入") ? secondary:ink);y+=105}
   else if s == "记住密码" || s.hasPrefix("我已阅读") {icon("square",20,y+2,18,green);paragraph(s,50,y,320,14,secondary);y+=48}
   else {paragraph(s,20,y,350,14,secondary);y+=s.count>28 ? 58:44}
  }
  if ["007","008"].contains(p.scene){text("退出登录",20,689,16,green,.medium,350,.center)}
 case "editor":
  text("正文",20,139,13,secondary,.medium);rect(20,175,350,272,color("F3F5F9"),12);paragraph(p.rows.first ?? "",36,195,318,17);text("",20,466,12,secondary)
 case "list","picker","search","activities":
  var y:CGFloat=130
  if ["picker","search","activities"].contains(p.kind){search(p.kind == "search" ? "集合":"搜索",126);y=190}
  if p.scene == "038" {filters(["文字","图片视频","文件"],186);text("选择成员",290,186,14,green);y=244}
  for(i,s) in p.rows.prefix(8).enumerated(){row(s,y+CGFloat(i)*74,p.kind == "picker",i,p.selected.contains(i),p.locked.contains(i))}
  if p.rows.count>8 {text("继续下滑查看其他设置",20,729,12,secondary)}
 case "detail":
  text(p.rows[0],20,145,28,ink,.semibold);text("户外 · 轻徒步",20,190,14,secondary)
  divider(236);icon("calendar",20,262,22,green);text(p.rows[1],58,262,17)
  icon("mappin.and.ellipse",20,314,22,green);text(p.rows[2],58,314,15,ink,.regular,310)
  divider(370);text("参与须知",20,401,19,ink,.semibold)
  for(i,s) in p.rows.dropFirst(3).enumerated(){paragraph(s,20,447+CGFloat(i)*78,350,16,secondary)}
 case "article":
  var y:CGFloat=144
  for(i,s) in p.rows.enumerated(){let head=i==0 || s.count<12;paragraph(s,20,y,350,head ? 22:16,head ? ink:secondary);y+=head ? 65:(s.count>45 ? 130:90)}
 case "person":
  avatar(String((p.rows.first ?? "夏").prefix(1)),145,155,1,100)
  text(p.rows.first ?? "",20,280,25,ink,.semibold,350,.center)
  var y:CGFloat=329
  for s in p.rows.dropFirst(){if s.contains("|"){row(s,y);y+=77}else{text(s,20,y,14,secondary,.regular,350,.center);y+=55}}
 case "result":
  let sym = p.variant == "error" ? "wifi.exclamationmark":p.variant == "empty" ? "magnifyingglass":p.variant == "file" ? "doc.text":p.variant == "audio" ? "waveform":p.variant == "loading" ? "arrow.trianglehead.2.clockwise.rotate.90":p.variant == "verify" ? "hand.draw":"checkmark.circle"
  icon(sym,157,208,76,green);text(p.rows.first ?? p.title,20,325,24,ink,.semibold,350,.center)
  for(i,s) in p.rows.dropFirst().enumerated(){paragraph(s,42,385+CGFloat(i)*77,306,16,secondary)}
 case "confirm":
  dialog(p.rows.first ?? p.title,p.rows.dropFirst().filter{$0 != "取消" && $0 != "继续编辑"}.joined(separator:"\n"),p.action.isEmpty ? "确认":p.action,p.scene == "118" ? "继续编辑":"取消",p.action.contains("删除") || p.action.contains("注销") || p.action.contains("解散"))
 case "qr":
  avatar(String((p.rows.first ?? "夏").prefix(1)),163,143,1,64);text(p.rows.first ?? "",20,231,23,ink,.semibold,350,.center);text(p.rows[1],20,274,13,secondary,.regular,350,.center)
  rect(70,327,250,250,color("F0F4FA"),14);icon("qrcode",116,370,158,ink);text("",20,602,13,secondary,.regular,350,.center);text("保存相册",38,681,17,green,.medium,140,.center);text("分享",212,681,17,green,.medium,140,.center)
 case "call":
  rect(0,0,390,844,color("142239"));text("9:41",25,16,14,.white,.semibold);icon("chevron.down",20,65,23,.white)
  text(p.rows[0],20,111,24,.white,.semibold,350,.center);text(p.rows[1],20,151,15,color("B4C3D8"),.regular,350,.center)
  if p.variant == "group" {for(i,n) in ["阿哲","陈默","林夏","林野"].enumerated(){let x:CGFloat=20+CGFloat(i%2)*180,y:CGFloat=224+CGFloat(i/2)*165;rect(x,y,170,150,color("20344F"),14);avatar(String(n.suffix(1)),x+55,y+28,i,60);text(n,x,y+106,15,.white,.regular,170,.center)}}
  else {avatar("哲",143,285,0,104);text(p.variant == "video" ? "视频画面示意":"语音通话",20,422,16,color("B4C3D8"),.regular,350,.center)}
  if p.variant == "incoming" {
   rect(55,722,110,58,color("B9413E"),29);rect(225,722,110,58,green,29)
   icon("phone.down",96,739,28,.white);icon("phone",266,739,28,.white)
   text("拒绝",55,792,14,.white,.medium,110,.center);text("接听",225,792,14,.white,.medium,110,.center)
  } else {
   let controls = p.variant == "video" ? [("mic.slash","静音"),("speaker.wave.2","扬声器"),("video","摄像头")]:[("mic.slash","静音"),("speaker.wave.2","扬声器")]
   for(i,n) in controls.enumerated(){let x=CGFloat(i)*110+40;icon(n.0,x+25,650,28,.white);text(n.1,x,692,13,.white,.regular,80,.center)}
   primary(p.action,754,true)
  }
 case "media":
  rect(0,108,390,630,color("15243A"))
  if p.variant == "stickers" {rect(0,108,390,630,white);text("最近使用    收藏表情",20,136,16,green);for i in 0..<12{icon(["face.smiling","heart","hand.thumbsup","sun.max"][i%4],CGFloat(i%4)*90+30,215+CGFloat(i/4)*110,46,green)}}
  else if p.variant == "map" {rect(20,144,350,432,color("E9EEF4"),12);icon("map",130,262,130,secondary);icon("mappin.circle.fill",173,300,45,green);text("地图内容示意",20,490,14,secondary,.regular,350,.center);text(p.rows[0],20,616,21,.white,.semibold)}
  else {rect(40,224,310,310,color("233B59"),p.variant == "crop" ? 0:12);icon(p.variant == "scanner" ? "viewfinder":p.variant == "video" ? "play.circle":"photo",139,330,112,color("C2D3E9"));text(p.rows.first ?? "媒体示例",20,570,16,.white,.regular,350,.center);text("媒体内容示意",20,610,12,color("B4C3D8"),.regular,350,.center)}
 default:break
 }
 if !p.action.isEmpty && p.kind != "call" && p.kind != "confirm" {primary(p.action,754,p.action.contains("注销") || p.action.contains("解散") || p.action.contains("清空") || p.action.contains("移除"),p.disabled)}
 if !top {rect(135,833,120,4,p.kind == "call" ? .white:ink,2)}
}
func png(_ width:CGFloat,_ height:CGFloat,_ url:URL,_ draw:()->Void) throws {
 let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(width*2),pixelsHigh:Int(height*2),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 let c=NSGraphicsContext(bitmapImageRep:rep)!.cgContext;c.scaleBy(x:2,y:2);c.translateBy(x:0,y:height);c.scaleBy(x:1,y:-1)
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:true);draw();NSGraphicsContext.restoreGraphicsState()
 try rep.representation(using:.png,properties:[:])!.write(to:url)
}
for p in pages {try png(390,844,dir.appendingPathComponent("screens/\(p.id).png")){drawPage(p)}}
let groups=Array(Set(pages.map{$0.group})).sorted()
for (gi,g) in groups.enumerated() {
 let group=pages.filter{$0.group==g}
 for start in stride(from:0,to:group.count,by:8) {
  let batch=Array(group[start..<min(start+8,group.count)]);let rows=CGFloat((batch.count+3)/4)
  try png(1752,115+rows*910,dir.appendingPathComponent("board-\(gi+1)-\(start/8+1).png")) {
   rect(0,0,1752,115+rows*910,color("EEF2F7"));text(g.dropFirst(3).description,36,30,26,ink,.semibold);text("岩白与钴蓝 / feature-newUI-5 · 业务校正版 / 静态设计 · 示例内容",900,39,13,secondary,.regular,812,.right)
   for(i,p) in batch.enumerated(){let x:CGFloat=36+CGFloat(i%4)*430,y:CGFloat=100+CGFloat(i/4)*910
    NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current!.cgContext.translateBy(x:x,y:y)
    let clip=NSBezierPath(roundedRect:NSRect(x:0,y:0,width:390,height:844),xRadius:18,yRadius:18);clip.addClip();drawPage(p);NSGraphicsContext.restoreGraphicsState()
    text(p.id+"  "+p.title,x,y+858,16,ink,.medium,390)
   }
  }
 }
}
print("Rendered \(pages.count) screens and group boards")
let picks=["012","028","031","096"].compactMap{id in pages.first{$0.id==id}}
try png(1752,1000,dir.appendingPathComponent("overview.png")) {
 rect(0,0,1752,1000,color("EEF2F7"));text("叮咚聊 · 岩白与钴蓝",36,25,27,ink,.semibold);text("业务流程与全页面设计 / feature-newUI-5 · 业务校正版",1020,36,14,secondary,.regular,696,.right)
 for(i,p) in picks.enumerated(){let x:CGFloat=36+CGFloat(i)*430
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current!.cgContext.translateBy(x:x,y:90);let clip=NSBezierPath(roundedRect:NSRect(x:0,y:0,width:390,height:844),xRadius:18,yRadius:18);clip.addClip();drawPage(p);NSGraphicsContext.restoreGraphicsState();text(p.title,x,952,17,ink,.medium)}
}
struct Flow:Decodable {let title,note:String;let ids:[String]}
let flows=try JSONDecoder().decode([Flow].self,from:Data(contentsOf:dir.appendingPathComponent("flows.json")))
for (n,f) in flows.enumerated() {
 try png(1752,1100,dir.appendingPathComponent("flow-\(n+1).png")) {
  rect(0,0,1752,1100,color("EEF2F7"));text(f.title,36,28,29,ink,.semibold,1100)
  text("叮咚聊 · 业务校正版 · 静态示例",1135,39,14,secondary,.regular,580,.right)
  text(f.note,36,75,16,secondary,.regular,1680)
  for(i,id) in f.ids.enumerated(){guard let p=pages.first(where:{$0.id==id}) else {continue};let x:CGFloat=36+CGFloat(i)*430,y:CGFloat=125
   NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current!.cgContext.translateBy(x:x,y:y)
   let clip=NSBezierPath(roundedRect:NSRect(x:0,y:0,width:390,height:844),xRadius:18,yRadius:18);clip.addClip();drawPage(p);NSGraphicsContext.restoreGraphicsState()
   text(p.title,x,988,18,ink,.semibold,390);paragraph(p.note,x,1023,390,13,secondary)
  }
 }
}
try png(512,512,dir.appendingPathComponent("brand/app-icon.png")){rect(0,0,512,512,green);brandMark(66.56,66.56,378.88,white)}
try png(512,512,dir.appendingPathComponent("brand/mark.png")){brandMark(0,0,512,green)}
try png(1752,1100,dir.appendingPathComponent("brand/identity.png")) {
 rect(0,0,1752,1100,white);text("叮咚聊",58,42,36,ink,.semibold);text("已选定 · 笑着聊",58,102,19,secondary)
 rect(62,233,462,462,green,103);brandMark(122.06,293.06,341.88,white)
 text("应用图标",62,749,21,ink,.semibold);paragraph("钴蓝底色，白色标志。系统负责图标圆角。",62,794,462,17,secondary)
 brandMark(748,220,256,green);brandWordmark(628,532,48,ink,500)
 divider(663,628,500);text("笑着聊，让对话更亲近。",628,702,24,ink,.semibold,500)
 paragraph("一个对话框，一道微笑。保留 D 方案的轮廓、留白和钴蓝配色。",628,754,500,18,secondary)
 text("小尺寸检视",1250,247,18,ink,.semibold,400)
 for(i,size) in [CGFloat(60),40,24].enumerated(){let y:CGFloat=315+CGFloat(i)*153;rect(1250,y,size,size,green,size*0.22);brandMark(1250+size*0.13,y+size*0.13,size*0.74,white);text("\(Int(size)) pt",1350,y+size/2-11,17,secondary)}
 text("单色标志 · 矢量绘制 · 尚未替换项目资产",58,1013,15,secondary,.regular,1400)
}
