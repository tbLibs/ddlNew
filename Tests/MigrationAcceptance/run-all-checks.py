# 独立执行所有离线脚本；结果写入临时目录，不含真实身份或认证信息。
from pathlib import Path
import subprocess
import json
import time
import argparse

qa_root = Path(__file__).resolve().parents[2]
qa_arguments = argparse.ArgumentParser(description='独立离线验收执行及日志目录')
qa_arguments.add_argument('--output', default='/tmp/ddlNew-migration-qa-results')
qa_logs = Path(qa_arguments.parse_args().output)
qa_logs.mkdir(exist_ok=True)
qa_scripts = sorted(qa_root.glob('Tests/*/run*-checks.sh'))
qa_results = []
for qa_script in qa_scripts:
    qa_label = str(qa_script.relative_to(qa_root))
    qa_log = qa_logs/(qa_label.replace('/', '-') + '.log')
    qa_started = time.monotonic()
    with qa_log.open('w') as qa_output:
        try:
            qa_run = subprocess.run(['sh', str(qa_script)], cwd=qa_root, stdout=qa_output, stderr=subprocess.STDOUT, timeout=180)
            qa_exit = qa_run.returncode
        except subprocess.TimeoutExpired:
            qa_exit = 124
    qa_results.append({'script': qa_label, 'exit': qa_exit, 'seconds': round(time.monotonic()-qa_started, 2), 'log': str(qa_log)})
    print(f'{"PASS" if qa_exit == 0 else "FAIL"} {qa_label} exit={qa_exit}', flush=True)
(qa_logs/'summary.json').write_text(json.dumps(qa_results, ensure_ascii=False, indent=2))
raise SystemExit(0 if all(qa_item['exit']==0 for qa_item in qa_results) else 1)
