// 只使用根已确认对应测试iPhone的8101本地WDA；不输入凭据或触碰原消息。
const { WebDriverAgent } = require('/Users/taobotaobo/.npm/_npx/3d55143a3497ce4a/node_modules/@mobilenext/mobile-mcp/lib/webdriver-agent.js');
const qaWda = new WebDriverAgent('127.0.0.1', 8101);

// 通知中心可能遮住已解锁应用，只有明确未锁定才允许关闭遮罩。
async function qaTree() {
    let rows = await qaWda.getElementsOnScreen();
    if (rows.some(row => row.label === '手电筒') && rows.some(row => row.label === '相机')) {
        const locked = await (await fetch('http://127.0.0.1:8101/wda/locked')).json();
        if (locked.value !== false) throw new Error('设备已锁定，停止测试，不输入解锁凭据');
        await qaWda.swipe('up'); rows = await qaWda.getElementsOnScreen();
    }
    return rows;
}

// 坐标只取本次真实控件边界，不按预想页面猜测点击。
async function qaTap(row) { await qaWda.tap(row.rect.x + row.rect.width / 2, row.rect.y + row.rect.height / 2); }

// 写操作只允许授权群内空输入框的新QA文本；导航与查看不改变账号归属。
async function main() {
    const [mode = 'inspect', target, marker] = process.argv.slice(2);
    let rows = await qaTree();
    if (mode === 'inspect') {
        console.log(JSON.stringify(rows.filter(row => row.rect.y < 110 || row.type === 'TextField' || row.label?.startsWith('QA_') || ['发送', '返回', '聊天设置', '我的', '消息', '通讯录'].includes(row.label)))); return;
    }
    if (mode === 'tap') {
        if (['退出登录', '更换俱乐部', '解散群聊', '清空聊天记录'].includes(target)) throw new Error('动作超出测试桥范围');
        const row = rows.find(row => row.type === 'Button' && row.label === target);
        if (!row) throw new Error('当前页面没有目标按钮'); await qaTap(row); console.log('已点击当前测试页面控件'); return;
    }
    if (mode !== 'send' || !/^QA_[A-Za-z0-9_ -]+$/.test(marker || '')) throw new Error('仅允许匿名QA标记消息');
    if (!rows.some(row => row.type === 'StaticText' && row.label === target && row.rect.y < 110)) throw new Error('当前不是指定授权群');
    const field = rows.find(row => row.type === 'TextField' && row.label === '消息正文');
    if (!field || !['发送消息', '', null].includes(field.value)) throw new Error('输入已有内容，停止以保留原草稿');
    await qaTap(field); await qaWda.sendKeys(marker); rows = await qaTree();
    if (rows.find(row => row.type === 'TextField' && row.label === '消息正文')?.value !== marker) throw new Error('输入标记未匹配，停止发送');
    const send = rows.find(row => row.type === 'Button' && row.label === '发送'); if (!send) throw new Error('没有发送按钮');
    await qaTap(send); rows = await qaTree();
    console.log(JSON.stringify({ marker, localCopies: rows.filter(row => row.type === 'StaticText' && row.label === marker).length,
        sendStateLabels: rows.filter(row => /发送中|发送失败|请求失败|超时/.test(row.label || '')).map(row => row.label) }));
}
main().catch(error => { console.error(error.message); process.exit(1); });
