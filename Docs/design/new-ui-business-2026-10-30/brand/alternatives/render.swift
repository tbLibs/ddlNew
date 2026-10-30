import AppKit

// Native vector proposals only. Does not touch app assets or source.
let output = URL(fileURLWithPath: CommandLine.arguments[1])
func color(_ hex:String)->NSColor {let n=UInt32(hex,radix:16)!;return NSColor(srgbRed:CGFloat(n>>16&255)/255,green:CGFloat(n>>8&255)/255,blue:CGFloat(n&255)/255,alpha:1)}
let blue=color("2859BC"), ink=color("182536"), grey=color("647184"), rule=color("DCE2EC")
func rect(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ c:NSColor,_ r:CGFloat=0){c.setFill();NSBezierPath(roundedRect:NSRect(x:x,y:y,width:w,height:h),xRadius:r,yRadius:r).fill()}
func text(_ s:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ c:NSColor=ink,_ weight:NSFont.Weight = .regular,_ w:CGFloat=330,_ align:NSTextAlignment = .left){let p=NSMutableParagraphStyle();p.alignment=align;(s as NSString).draw(in:NSRect(x:x,y:y,width:w,height:size*2),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:c,.paragraphStyle:p])}
final class Shape {
 let p=NSBezierPath(); var d=""
 init(){p.windingRule = .evenOdd}
 @discardableResult func m(_ x:CGFloat,_ y:CGFloat)->Shape{p.move(to:NSPoint(x:x,y:y));d+="M\(x) \(y) ";return self}
 @discardableResult func l(_ x:CGFloat,_ y:CGFloat)->Shape{p.line(to:NSPoint(x:x,y:y));d+="L\(x) \(y) ";return self}
 @discardableResult func c(_ a:CGFloat,_ b:CGFloat,_ c:CGFloat,_ e:CGFloat,_ x:CGFloat,_ y:CGFloat)->Shape{p.curve(to:NSPoint(x:x,y:y),controlPoint1:NSPoint(x:a,y:b),controlPoint2:NSPoint(x:c,y:e));d+="C\(a) \(b) \(c) \(e) \(x) \(y) ";return self}
 @discardableResult func z()->Shape{p.close();d+="Z ";return self}
}
func shapes(_ id:Int)->[Shape]{
 switch id {
 case 0:
  // A: a custom geometric 叮, with a low, open 丁 hook.
  let mouth=Shape().m(30,66).l(101,66).c(107,66,110,69,110,75).l(110,174).c(110,180,107,183,101,183).l(30,183).c(24,183,21,180,21,174).l(21,75).c(21,69,24,66,30,66).z()
  mouth.m(49,94).l(82,94).l(82,155).l(49,155).z()
  let ding=Shape().m(129,54).l(229,54).l(229,83).l(199,83).l(199,177).c(199,202,187,215,163,215).l(145,215).l(135,185).l(158,185).c(166,185,169,181,169,173).l(169,83).l(129,83).z()
  return [mouth,ding]
 case 1:
  // B: a compact bell, without eyes, sparkles or decoration.
  let bell=Shape().m(119,37).c(119,32,137,32,137,37).l(140,49).c(170,55,189,79,189,110).l(189,136).c(189,153,195,166,207,179).c(211,184,208,192,201,192).l(55,192).c(48,192,45,184,49,179).c(61,166,67,153,67,136).l(67,110).c(67,79,86,55,116,49).z()
  // Deliberately off-centre, broad aperture: a bell heard in motion.
  bell.m(105,81).c(91,89,87,101,87,120).l(87,141).l(104,141).l(104,118).c(104,105,106,99,113,94).z()
  let clapper=Shape().m(106,205).l(150,205).c(147,224,111,224,106,205).z()
  return [bell,clapper]
 case 2:
  // C: two alternating quotation strokes, not two nested chat bubbles.
  let left=Shape().m(109,45).l(109,91).c(85,91,71,101,71,120).l(109,120).l(109,190).l(40,190).l(40,129).c(40,80,65,48,109,45).z()
  let right=Shape().m(147,211).l(147,165).c(171,165,185,155,185,136).l(147,136).l(147,66).l(216,66).l(216,127).c(216,176,191,208,147,211).z()
  return [left,right]
 default:
  // D: one friendly open conversation; asymmetric tail and a broad smile.
  let speech=Shape().m(128,34).c(185,34,224,71,224,121).c(224,174,183,211,129,211).c(113,211,99,208,86,202).l(43,223).l(51,180).c(38,165,32,144,32,121).c(32,71,72,34,128,34).z()
  speech.m(76,120).c(80,151,101,170,128,170).c(156,170,177,151,181,120).l(158,120).c(154,138,144,148,128,148).c(112,148,102,138,99,120).z()
  return [speech]
 }
}
func mark(_ id:Int,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ c:NSColor){NSGraphicsContext.saveGraphicsState();let g=NSGraphicsContext.current!.cgContext;g.translateBy(x:x,y:y);g.scaleBy(x:size/256,y:size/256);c.setFill();for s in shapes(id){s.p.fill()};NSGraphicsContext.restoreGraphicsState()}
func appIcon(_ id:Int,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ rounded:Bool=true){rect(x,y,size,size,blue,rounded ? size*0.225:0);mark(id,x+size*0.13,y+size*0.13,size*0.74,.white)}
func png(_ name:String,_ width:CGFloat,_ height:CGFloat,_ draw:()->Void)throws{let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(width*2),pixelsHigh:Int(height*2),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!;let c=NSGraphicsContext(bitmapImageRep:rep)!.cgContext;c.scaleBy(x:2,y:2);c.translateBy(x:0,y:height);c.scaleBy(x:1,y:-1);NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:true);draw();NSGraphicsContext.restoreGraphicsState();try rep.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name))}
let names=["A · 一声叮","B · 响铃","C · 你来我往","D · 笑着聊"]
let descriptions=["从「叮」字直接提炼，偏利落、有分量。","把叮咚的声音变成标志，轻快而直接。","一对错位引号，让对话有来有往。","一个微笑的对话框，更亲近、放松。"]
try png("comparison.png",1600,990){
 rect(0,0,1600,990,.white)
 text("叮咚聊",54,40,38,ink,.semibold)
 text("四种新方向",54,96,20,grey)
 text("同一钴蓝 · 先比较轮廓与气质",1110,104,16,grey,.regular,430,.right)
 rect(54,150,1492,1,rule)
 for i in 0..<4 {let x=CGFloat(i)*386+54
  text(names[i],x,184,23,ink,.semibold,350)
  appIcon(i,x+39,247,270)
  mark(i,x+25,559,92,blue);text("叮咚聊",x+134,585,31,ink,.semibold,210)
  text(descriptions[i],x,684,15,grey,.regular,350)
  rect(x,746,334,1,rule)
  for (j,s) in [CGFloat(60),40,24].enumerated(){let sx=x+CGFloat(j)*113+18;appIcon(i,sx,798+(60-s)/2,s);text("\(Int(s)) pt",sx-10,879,13,grey,.regular,s+20,.center)}
 }
 text("静态候选稿 · 尚未选定 · 图标以 @2x 渲染，小尺寸请在原始比例查看",54,944,13,grey,.regular,1400)
}
try png("startup-comparison.png",1600,1050){
 rect(0,0,1600,1050,color("F2F4F8"));text("放进启动页，再看一眼",54,38,32,ink,.semibold,1000)
 text("白底、无口号；保持同一构图，只更换标志。",54,91,17,grey,.regular,1200)
 for i in 0..<4 {let x=CGFloat(i)*386+54
  text(names[i],x,151,22,ink,.semibold)
  rect(x,209,334,724,rule,32);rect(x+1,210,332,722,.white,31)
  mark(i,x+109,435,116,blue);text("叮咚聊",x+25,578,27,ink,.semibold,284,.center)
  rect(x+115,912,104,4,ink,2)
 }
 text("设计预览 · 未替换应用图标或启动页 · 未新增启动等待时长",54,990,14,grey,.regular,1400)
}
for i in 0..<4 {
 let slug=["a-ding","b-bell","c-dialogue","d-smile"][i]
 try png("\(slug)-icon.png",512,512){appIcon(i,0,0,512,false)}
 try png("\(slug)-mark.png",256,256){mark(i,0,0,256,blue)}
 let paths=shapes(i).map{"<path fill-rule=\"evenodd\" d=\"\($0.d)\"/>"}.joined(separator:"\n")
 try "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 256 256\" fill=\"#2859BC\"><title>叮咚聊 · \(names[i])</title>\n\(paths)\n</svg>".write(to:output.appendingPathComponent("\(slug).svg"),atomically:true,encoding:.utf8)
}
print("Rendered four vector candidates and two comparison boards.")
