from flask import Flask, render_template, request, redirect, url_for, session, flash
from flask_mysqldb import MySQL
import MySQLdb.cursors
from functools import wraps
import os
import hashlib

app = Flask(__name__)

app.secret_key = os.urandom(24)

app.config['MYSQL_HOST'] = 'localhost'
app.config['MYSQL_USER'] = 'root'
app.config['MYSQL_PASSWORD'] = '123456'
app.config['MYSQL_DB'] = 'research_project_db'
app.config['MYSQL_CURSORCLASS'] = 'DictCursor'

mysql = MySQL(app)

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

@app.route('/')
def index():
    if 'user_id' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        cursor.execute('SELECT * FROM users WHERE username = %s', (username,))
        user = cursor.fetchone()
        
        password_md5 = hashlib.md5(password.encode()).hexdigest()
        
        if user and user['password'] == password_md5:
            session['user_id'] = user['user_id']
            session['username'] = user['username']
            session['real_name'] = user['real_name']
            session['role'] = user['role']
            flash('登录成功！', 'success')
            return redirect(url_for('dashboard'))
        else:
            flash('用户名或密码错误！', 'error')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    flash('已退出登录！', 'info')
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    role = session['role']
    
    if role == '科研人员':
        return redirect(url_for('researcher_dashboard'))
    elif role == '项目负责人':
        return redirect(url_for('leader_dashboard'))
    elif role == '科研机构管理员':
        return redirect(url_for('admin_dashboard'))
    
    return redirect(url_for('login'))

@app.route('/researcher')
@login_required
def researcher_dashboard():
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    
    cursor.execute('SELECT * FROM v_researcher_tasks WHERE researcher_id = %s', (session['user_id'],))
    tasks = cursor.fetchall()
    
    cursor.execute('SELECT DISTINCT * FROM v_researcher_projects WHERE project_id IN (SELECT project_id FROM tasks WHERE researcher_id = %s)', (session['user_id'],))
    projects = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_researcher_reimbursements WHERE applicant_id = %s', (session['user_id'],))
    reimbursements = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_researcher_achievements WHERE submitter_id = %s', (session['user_id'],))
    achievements = cursor.fetchall()
    
    return render_template('researcher/dashboard.html', 
                          tasks=tasks, 
                          projects=projects, 
                          reimbursements=reimbursements, 
                          achievements=achievements)

@app.route('/leader')
@login_required
def leader_dashboard():
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    
    cursor.execute('SELECT * FROM v_leader_projects WHERE leader_id = %s', (session['user_id'],))
    projects = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_researchers')
    researchers = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_leader_pending_reimbursements WHERE project_id IN (SELECT project_id FROM projects WHERE leader_id = %s)', (session['user_id'],))
    pending_reimbursements = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_leader_pending_achievements WHERE project_id IN (SELECT project_id FROM projects WHERE leader_id = %s)', (session['user_id'],))
    pending_achievements = cursor.fetchall()
    
    return render_template('leader/dashboard.html', 
                          projects=projects, 
                          researchers=researchers,
                          pending_reimbursements=pending_reimbursements,
                          pending_achievements=pending_achievements)

@app.route('/project/<int:project_id>')
@login_required
def project_detail(project_id):
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    
    cursor.execute('SELECT * FROM projects WHERE project_id = %s AND leader_id = %s', (project_id, session['user_id']))
    project = cursor.fetchone()
    
    if not project:
        flash('项目不存在或无权访问', 'error')
        return redirect(url_for('leader_dashboard'))
    
    cursor.execute('SELECT IFNULL(SUM(amount), 0) as total_reimbursed FROM reimbursements WHERE project_id = %s AND status = %s', (project_id, '已通过'))
    result = cursor.fetchone()
    total_reimbursed = result['total_reimbursed']
    reimbursement_percentage = (total_reimbursed / project['budget'] * 100) if project['budget'] > 0 else 0
    
    cursor.execute('SELECT * FROM v_project_researchers_tasks WHERE user_id IN (SELECT researcher_id FROM tasks WHERE project_id = %s)', (project_id,))
    researchers_with_tasks = cursor.fetchall()
    
    for rwt in researchers_with_tasks:
        if rwt['task_list']:
            rwt['tasks'] = []
            for task_str in rwt['task_list'].split('||'):
                parts = task_str.split('|')
                if len(parts) == 4:
                    rwt['tasks'].append({
                        'task_id': parts[0],
                        'task_content': parts[1],
                        'deadline': parts[2],
                        'status': parts[3]
                    })
        else:
            rwt['tasks'] = []
    
    cursor.execute('SELECT * FROM v_project_tasks WHERE project_id = %s', (project_id,))
    tasks = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_project_reimbursements WHERE project_id = %s', (project_id,))
    reimbursements = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_project_achievements WHERE project_id = %s', (project_id,))
    achievements = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_researchers')
    researchers = cursor.fetchall()
    
    return render_template('leader/project_detail.html', 
                          project=project,
                          tasks=tasks, 
                          reimbursements=reimbursements, 
                          achievements=achievements,
                          researchers=researchers,
                          researchers_with_tasks=researchers_with_tasks,
                          total_reimbursed=total_reimbursed,
                          reimbursement_percentage=reimbursement_percentage)

@app.route('/admin')
@login_required
def admin_dashboard():
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    
    cursor.execute('SELECT * FROM v_admin_projects')
    projects = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_all_users')
    users = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_admin_statistics')
    stats = cursor.fetchone()
    
    cursor.execute('SELECT * FROM v_admin_reimbursements')
    reimbursements = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_admin_achievements')
    achievements = cursor.fetchall()
    
    return render_template('admin/dashboard.html', 
                          projects=projects, 
                          users=users, 
                          stats=stats,
                          reimbursements=reimbursements,
                          achievements=achievements)

@app.route('/task/update/<int:task_id>', methods=['POST'])
@login_required
def update_task(task_id):
    status = request.form['status']
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    try:
        cursor.callproc('sp_update_task', [task_id, status, session['user_id'], 0])
        cursor.execute('SELECT @_sp_update_task_3')
        result = cursor.fetchone()
        flash(result['@_sp_update_task_3'], 'success' if '成功' in result['@_sp_update_task_3'] else 'error')
    except Exception as e:
        mysql.connection.rollback()
        flash(str(e), 'error')
    return redirect(url_for('researcher_dashboard'))

@app.route('/reimbursement/apply', methods=['POST'])
@login_required
def apply_reimbursement():
    project_id = request.form['project_id']
    amount = request.form['amount']
    reason = request.form['reason']
    
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    try:
        cursor.callproc('sp_apply_reimbursement_new', [project_id, session['user_id'], amount, reason, 0])
        cursor.execute('SELECT @_sp_apply_reimbursement_new_4')
        result = cursor.fetchone()
        flash(result['@_sp_apply_reimbursement_new_4'], 'success' if '成功' in result['@_sp_apply_reimbursement_new_4'] else 'error')
    except Exception as e:
        mysql.connection.rollback()
        flash(str(e), 'error')
    return redirect(url_for('researcher_dashboard'))

@app.route('/achievement/submit', methods=['POST'])
@login_required
def submit_achievement():
    project_id = request.form['project_id']
    title = request.form['title']
    type = request.form['type']
    publish_date = request.form['publish_date']
    
    import re
    if not re.match(r'^\d{4}-\d{2}-\d{2}$', publish_date):
        flash('日期格式错误，请输入 YYYY-MM-DD 格式的日期（如：2024-03-31）', 'error')
        return redirect(url_for('researcher_dashboard'))
    
    try:
        from datetime import datetime
        datetime.strptime(publish_date, '%Y-%m-%d')
    except ValueError:
        flash('无效的日期，请输入有效的日期（如：2024-03-31）', 'error')
        return redirect(url_for('researcher_dashboard'))
    
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    try:
        cursor.callproc('sp_submit_achievement_new', [project_id, session['user_id'], title, type, publish_date, 0])
        cursor.execute('SELECT @_sp_submit_achievement_new_5')
        result = cursor.fetchone()
        flash(result['@_sp_submit_achievement_new_5'], 'success' if '成功' in result['@_sp_submit_achievement_new_5'] else 'error')
    except Exception as e:
        mysql.connection.rollback()
        flash(str(e), 'error')
    return redirect(url_for('researcher_dashboard'))

@app.route('/project/add', methods=['POST'])
@login_required
def add_project():
    project_name = request.form['project_name']
    description = request.form['description']
    budget = request.form['budget']
    
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    try:
        cursor.callproc('sp_add_project', [project_name, description, budget, session['user_id'], 0])
        cursor.execute('SELECT @_sp_add_project_4')
        result = cursor.fetchone()
        flash(result['@_sp_add_project_4'], 'success' if '成功' in result['@_sp_add_project_4'] else 'error')
    except Exception as e:
        mysql.connection.rollback()
        flash(str(e), 'error')
    return redirect(url_for('leader_dashboard'))

@app.route('/project/update/<int:project_id>', methods=['POST'])
@login_required
def update_project(project_id):
    project_name = request.form['project_name']
    description = request.form['description']
    budget = request.form['budget']
    
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    try:
        cursor.callproc('sp_update_project', [project_id, project_name, description, budget, session['user_id'], 0])
        cursor.execute('SELECT @_sp_update_project_5')
        result = cursor.fetchone()
        flash(result['@_sp_update_project_5'], 'success' if '成功' in result['@_sp_update_project_5'] else 'error')
    except Exception as e:
        mysql.connection.rollback()
        flash(str(e), 'error')
    return redirect(url_for('project_detail', project_id=project_id))

@app.route('/project/complete/<int:project_id>', methods=['POST'])
@login_required
def request_complete(project_id):
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    try:
        cursor.callproc('sp_request_complete', [project_id, session['user_id'], 0])
        cursor.execute('SELECT @_sp_request_complete_2')
        result = cursor.fetchone()
        message = result['@_sp_request_complete_2']
        flash(message, 'success' if '失败' not in message and '错误' not in message else 'error')
    except Exception as e:
        mysql.connection.rollback()
        flash(str(e), 'error')
    return redirect(url_for('project_detail', project_id=project_id))

@app.route('/task/assign', methods=['POST'])
@login_required
def assign_task():
    project_id = request.form['project_id']
    researcher_id = request.form['researcher_id']
    task_content = request.form['task_content']
    deadline = request.form['deadline']
    
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    try:
        cursor.callproc('sp_assign_task', [project_id, researcher_id, task_content, deadline, 0])
        cursor.execute('SELECT @_sp_assign_task_4')
        result = cursor.fetchone()
        message = result['@_sp_assign_task_4']
        category = 'success' if '成功' in message else 'error'
        flash(message, category)
    except Exception as e:
        mysql.connection.rollback()
        flash(str(e), 'error')
    return redirect(url_for('project_detail', project_id=project_id))

@app.route('/review/reimbursement/<int:reimb_id>', methods=['POST'])
@login_required
def review_reimbursement(reimb_id):
    action = request.form['action']
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    try:
        cursor.callproc('sp_review_reimbursement', [reimb_id, action.upper(), 0, 0])
        cursor.execute('SELECT @_sp_review_reimbursement_2, @_sp_review_reimbursement_3')
        result = cursor.fetchone()
        message = result['@_sp_review_reimbursement_2']
        project_id = result['@_sp_review_reimbursement_3']
        category = 'success' if '通过' in message or '驳回' in message else 'error'
        flash(message, category)
    except Exception as e:
        mysql.connection.rollback()
        flash(str(e), 'error')
        project_id = None
    
    if session['role'] == '科研机构管理员':
        return redirect(url_for('admin_dashboard'))
    elif project_id:
        return redirect(url_for('project_detail', project_id=project_id))
    return redirect(url_for('leader_dashboard'))

@app.route('/review/achievement/<int:achievement_id>', methods=['POST'])
@login_required
def review_achievement(achievement_id):
    action = request.form['action']
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    try:
        cursor.callproc('sp_review_achievement', [achievement_id, action.upper(), 0, 0])
        cursor.execute('SELECT @_sp_review_achievement_2, @_sp_review_achievement_3')
        result = cursor.fetchone()
        message = result['@_sp_review_achievement_2']
        project_id = result['@_sp_review_achievement_3']
        category = 'success' if '通过' in message or '驳回' in message else 'error'
        flash(message, category)
    except Exception as e:
        mysql.connection.rollback()
        flash(str(e), 'error')
        project_id = None
    
    if session['role'] == '科研机构管理员':
        return redirect(url_for('admin_dashboard'))
    elif project_id:
        return redirect(url_for('project_detail', project_id=project_id))
    return redirect(url_for('leader_dashboard'))

@app.route('/admin/project/review/<int:project_id>', methods=['POST'])
@login_required
def review_project(project_id):
    action = request.form['action']
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    try:
        cursor.callproc('sp_review_project', [project_id, action.upper(), 0])
        cursor.execute('SELECT @_sp_review_project_2')
        result = cursor.fetchone()
        message = result['@_sp_review_project_2']
        category = 'success' if '通过' in message or '驳回' in message else 'error'
        flash(message, category)
    except Exception as e:
        mysql.connection.rollback()
        flash(str(e), 'error')
    return redirect(url_for('admin_dashboard'))

@app.route('/admin/user/add', methods=['POST'])
@login_required
def add_user():
    username = request.form['username']
    password = request.form['password']
    real_name = request.form['real_name']
    role = request.form['role']
    department = request.form['department']
    
    password_md5 = hashlib.md5(password.encode()).hexdigest()
    
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    try:
        cursor.callproc('sp_add_user', [username, password_md5, real_name, role, department, 0])
        cursor.execute('SELECT @_sp_add_user_5')
        result = cursor.fetchone()
        flash(result['@_sp_add_user_5'], 'success' if '成功' in result['@_sp_add_user_5'] else 'error')
    except Exception as e:
        mysql.connection.rollback()
        flash(str(e), 'error')
    return redirect(url_for('admin_dashboard'))

@app.route('/admin/user/delete/<int:user_id>', methods=['POST'])
@login_required
def delete_user(user_id):
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    try:
        cursor.callproc('sp_delete_user', [user_id, 0])
        cursor.execute('SELECT @_sp_delete_user_1')
        result = cursor.fetchone()
        flash(result['@_sp_delete_user_1'], 'success' if '成功' in result['@_sp_delete_user_1'] else 'error')
    except Exception as e:
        mysql.connection.rollback()
        flash(str(e), 'error')
    return redirect(url_for('admin_dashboard'))

@app.route('/admin/project/detail/<int:project_id>')
@login_required
def admin_project_detail(project_id):
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    
    cursor.execute('SELECT * FROM v_admin_projects WHERE project_id = %s', (project_id,))
    project = cursor.fetchone()
    
    cursor.execute('SELECT * FROM v_project_tasks WHERE project_id = %s', (project_id,))
    tasks = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_project_reimbursements WHERE project_id = %s', (project_id,))
    reimbursements = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_project_achievements WHERE project_id = %s', (project_id,))
    achievements = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_researchers WHERE user_id IN (SELECT DISTINCT researcher_id FROM tasks WHERE project_id = %s)', (project_id,))
    researchers = cursor.fetchall()
    
    return render_template('admin/project_detail.html', 
                          project=project,
                          tasks=tasks, 
                          reimbursements=reimbursements, 
                          achievements=achievements,
                          researchers=researchers)

@app.route('/admin/user/detail/<int:user_id>')
@login_required
def admin_user_detail(user_id):
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    
    cursor.execute('SELECT * FROM v_all_users WHERE user_id = %s', (user_id,))
    user = cursor.fetchone()
    
    cursor.execute('SELECT * FROM v_researcher_tasks WHERE researcher_id = %s', (user_id,))
    tasks = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_researcher_achievements WHERE submitter_id = %s', (user_id,))
    achievements = cursor.fetchall()
    
    cursor.execute('SELECT * FROM v_researcher_reimbursements WHERE applicant_id = %s', (user_id,))
    reimbursements = cursor.fetchall()
    
    if user['role'] == '项目负责人':
        cursor.execute('SELECT * FROM v_leader_projects WHERE leader_id = %s', (user_id,))
        led_projects = cursor.fetchall()
    else:
        led_projects = []
    
    return render_template('admin/user_detail.html', 
                          user=user,
                          tasks=tasks, 
                          achievements=achievements,
                          reimbursements=reimbursements,
                          led_projects=led_projects)

@app.route('/admin/user/update_role/<int:user_id>', methods=['POST'])
@login_required
def update_user_role(user_id):
    new_role = request.form['role']
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    try:
        cursor.callproc('sp_update_user_role', [user_id, new_role, 0])
        cursor.execute('SELECT @_sp_update_user_role_2')
        result = cursor.fetchone()
        flash(result['@_sp_update_user_role_2'], 'success' if '成功' in result['@_sp_update_user_role_2'] else 'error')
    except Exception as e:
        mysql.connection.rollback()
        flash(str(e), 'error')
    return redirect(url_for('admin_dashboard'))

import csv
import io
from datetime import datetime
from flask import Response

from urllib.parse import quote

from flask import jsonify

def create_csv_response(data, headers, filename):
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(headers)
    writer.writerows(data)
    
    # 对中文文件名进行 URL 编码
    safe_filename = quote(f'{filename}_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv')
    
    return Response(
        output.getvalue().encode('utf-8-sig'),
        mimetype='text/csv',
        headers={'Content-Disposition': f"attachment; filename*=UTF-8''{safe_filename}"}
    )

@app.route('/admin/export/projects')
@login_required
def export_projects():
    if session.get('role') != '科研机构管理员':
        flash('无权访问', 'error')
        return redirect(url_for('dashboard'))
    
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    cursor.execute('SELECT * FROM v_admin_projects')
    projects = cursor.fetchall()
    
    headers = ['项目ID', '项目名称', '负责人', '预算', '已报销', '任务数', '成果数', '状态', '申报日期']
    data = []
    for p in projects:
        data.append([
            p['project_id'],
            p['project_name'],
            p['leader_name'],
            p['budget'],
            p['total_reimbursement'] or 0,
            p['task_count'],
            p['achievement_count'],
            p['status'],
            p['apply_date']
        ])
    
    return create_csv_response(data, headers, '项目数据')

@app.route('/admin/export/users')
@login_required
def export_users():
    if session.get('role') != '科研机构管理员':
        flash('无权访问', 'error')
        return redirect(url_for('dashboard'))
    
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    cursor.execute('SELECT * FROM v_all_users')
    users = cursor.fetchall()
    
    headers = ['用户ID', '用户名', '真实姓名', '角色', '部门', '任务数', '成果数']
    data = []
    for u in users:
        data.append([
            u['user_id'],
            u['username'],
            u['real_name'],
            u['role'],
            u['department'] or '',
            u['task_count'],
            u['achievement_count']
        ])
    
    return create_csv_response(data, headers, '用户数据')

@app.route('/admin/export/reimbursements')
@login_required
def export_reimbursements():
    if session.get('role') != '科研机构管理员':
        flash('无权访问', 'error')
        return redirect(url_for('dashboard'))
    
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    cursor.execute('SELECT * FROM v_admin_reimbursements')
    reimbursements = cursor.fetchall()
    
    headers = ['报销单号', '项目名称', '申请人', '金额', '事由', '申请日期', '状态']
    data = []
    for r in reimbursements:
        data.append([
            r['reimb_id'],
            r['project_name'],
            r['applicant_name'],
            r['amount'],
            r['reason'],
            r['apply_date'],
            r['status']
        ])
    
    return create_csv_response(data, headers, '报销数据')

@app.route('/admin/export/achievements')
@login_required
def export_achievements():
    if session.get('role') != '科研机构管理员':
        flash('无权访问', 'error')
        return redirect(url_for('dashboard'))
    
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    cursor.execute('SELECT * FROM v_admin_achievements')
    achievements = cursor.fetchall()
    
    headers = ['成果ID', '项目名称', '提交人', '成果名称', '类型', '发表日期', '状态']
    data = []
    for a in achievements:
        data.append([
            a['achievement_id'],
            a['project_name'],
            a['submitter_name'],
            a['title'],
            a['type'],
            a['publish_date'] or '未设置',
            a['status']
        ])
    
    return create_csv_response(data, headers, '成果数据')

@app.route('/api/admin/trend-data')
@login_required
def get_admin_trend_data():
    # 验证用户权限
    if session.get('role') != '科研机构管理员':
        return jsonify({'error': '无权访问'}), 403
    
    from datetime import datetime, timedelta
    import calendar
    
    # 计算近7天的日期
    dates = []
    today = datetime.now()
    for i in range(6, -1, -1):
        date = today - timedelta(days=i)
        dates.append(date.strftime('%m-%d'))
    
    # 初始化数据字典
    project_data = {date: 0 for date in dates}
    reimbursement_data = {date: 0 for date in dates}
    achievement_data = {date: 0 for date in dates}
    
    cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
    
    # 查询项目数据
    start_date = (today - timedelta(days=6)).strftime('%Y-%m-%d')
    end_date = today.strftime('%Y-%m-%d')
    
    # 项目数
    cursor.execute('''
        SELECT DATE(apply_date) as date, COUNT(*) as count 
        FROM projects 
        WHERE apply_date BETWEEN %s AND %s 
        GROUP BY DATE(apply_date)
    ''', (start_date, end_date))
    project_results = cursor.fetchall()
    for result in project_results:
        date_str = result['date'].strftime('%m-%d')
        if date_str in project_data:
            project_data[date_str] = result['count']
    
    # 报销数
    cursor.execute('''
        SELECT DATE(apply_date) as date, COUNT(*) as count 
        FROM reimbursements 
        WHERE apply_date BETWEEN %s AND %s 
        GROUP BY DATE(apply_date)
    ''', (start_date, end_date))
    reimbursement_results = cursor.fetchall()
    for result in reimbursement_results:
        date_str = result['date'].strftime('%m-%d')
        if date_str in reimbursement_data:
            reimbursement_data[date_str] = result['count']
    
    # 成果数
    cursor.execute('''
        SELECT DATE(publish_date) as date, COUNT(*) as count 
        FROM achievements 
        WHERE publish_date BETWEEN %s AND %s 
        GROUP BY DATE(publish_date)
    ''', (start_date, end_date))
    achievement_results = cursor.fetchall()
    for result in achievement_results:
        date_str = result['date'].strftime('%m-%d')
        if date_str in achievement_data:
            achievement_data[date_str] = result['count']
    
    # 转换为列表
    project_list = [project_data[date] for date in dates]
    reimbursement_list = [reimbursement_data[date] for date in dates]
    achievement_list = [achievement_data[date] for date in dates]
    
    return jsonify({
        'dates': dates,
        'projects': project_list,
        'reimbursements': reimbursement_list,
        'achievements': achievement_list
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')
