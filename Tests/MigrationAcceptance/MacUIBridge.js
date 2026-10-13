// 仅控制用户授权的ddlNew窗口，不读取剪贴板或安全输入内容。
const qaApp = Application('System Events').processes.byName('ddlNew');
const qaWindow = qaApp.windows.byName('叮咚聊');

// AX缺少属性时返回空，不把其他应用或系统元素纳入查找。
function qaRead(element, property) { try { return element[property](); } catch (error) { return null; } }

// UIKit的Mac包装可超过20层，按精确描述和真实角色定位控件。
function qaFind(element, description, depth, prefix) {
    if (depth > 65) return null;
    const role = qaRead(element, 'role');
    const label = qaRead(element, 'description');
    const matches = prefix ? label && (label.startsWith(description + '，') || label === description) : label === description;
    if (matches && ['AXRadioButton', 'AXButton', 'AXPopUpButton', 'AXTextField', 'AXTextArea'].includes(role)) return element;
    for (const child of qaRead(element, 'uiElements') || []) { const found = qaFind(child, description, depth + 1, prefix); if (found) return found; }
    return null;
}

// 只读语义叶节点，安全字段始终不访问value，数据只返回给当前工具调用。
function qaInspect(element, rows, depth) {
    if (depth > 65 || rows.length > 160) return;
    const role = qaRead(element, 'role');
    if (['AXRadioButton', 'AXButton', 'AXPopUpButton', 'AXTextField', 'AXTextArea', 'AXStaticText', 'AXHeading'].includes(role)) {
        rows.push({ role, label: qaRead(element, 'description'), value: qaRead(element, 'value'), position: qaRead(element, 'position'), size: qaRead(element, 'size') });
    }
    for (const child of qaRead(element, 'uiElements') || []) qaInspect(child, rows, depth + 1);
}

// 所有操作限定应用和窗口；输入仅接受QA标记ASCII，不可用于账号、密码或原历史内容。
function run(argv) {
    const mode = argv[0] || 'inspect';
    if (mode === 'inspect') { const rows = []; qaInspect(qaWindow, rows, 0); return JSON.stringify(rows); }
    const label = argv[1];
    if (['退出登录', '更换俱乐部', '解散群聊', '清空聊天记录'].includes(label)) throw new Error('该动作不属于此测试桥范围');
    const element = qaFind(qaWindow, label, 0, mode === 'click-prefix');
    if (!element) throw new Error('当前测试窗口找不到指定控件');
    qaApp.frontmost = true;
    if (mode === 'click' || mode === 'click-prefix') { element.actions.byName('AXPress').perform(); return '已操作当前测试窗口控件'; }
    if (mode === 'type') {
        const text = argv[2] || '';
        if (!/^QA_[A-Za-z0-9_ -]+$/.test(text)) throw new Error('仅允许匿名QA标记文本');
        if (!['AXTextField', 'AXTextArea'].includes(qaRead(element, 'role'))) throw new Error('目标不是普通文本输入');
        element.focused = true;
        if (!qaApp.frontmost()) throw new Error('测试应用不是前台，停止输入');
        Application('System Events').keystroke(text);
        return '已输入匿名QA标记';
    }
    throw new Error('未知测试桥动作');
}
