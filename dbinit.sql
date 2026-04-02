-- 1. 创建并使用数据库
DROP DATABASE IF EXISTS `research_project_db`;
CREATE DATABASE IF NOT EXISTS `research_project_db`
CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

USE `research_project_db`;

-- 2.1 用户表
CREATE TABLE `users` (
    `user_id` INT AUTO_INCREMENT PRIMARY KEY COMMENT '用户唯一编号',
    `username` VARCHAR(50) NOT NULL UNIQUE COMMENT '登录账号',
    `password` VARCHAR(255) NOT NULL COMMENT '登录密码',
    `real_name` VARCHAR(50) NOT NULL COMMENT '真实姓名',
    `role` ENUM('科研人员', '项目负责人', '科研机构管理员') NOT NULL COMMENT '用户角色',
    `department` VARCHAR(100) COMMENT '所属部门'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户信息表';

-- 2.2 项目表
CREATE TABLE `projects` (
    `project_id` INT AUTO_INCREMENT PRIMARY KEY COMMENT '项目唯一编号',
    `project_name` VARCHAR(200) NOT NULL UNIQUE COMMENT '项目名称',
    `description` TEXT COMMENT '项目简介',
    `budget` DECIMAL(10, 2) NOT NULL COMMENT '项目总预算',
    `status` ENUM('申报中', '执行中', '已结题', '已驳回') DEFAULT '申报中' COMMENT '当前状态',
    `leader_id` INT COMMENT '项目负责人ID',
    `apply_date` DATE COMMENT '申报日期',
    FOREIGN KEY (`leader_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='科研项目表';

-- 2.3 任务表
CREATE TABLE `tasks` (
    `task_id` INT AUTO_INCREMENT PRIMARY KEY COMMENT '任务唯一编号',
    `project_id` INT COMMENT '所属项目ID',
    `researcher_id` INT COMMENT '执行任务的科研人员ID',
    `task_content` TEXT NOT NULL COMMENT '任务具体内容',
    `deadline` DATE COMMENT '截止日期',
    `status` ENUM('未开始', '进行中', '已完成') DEFAULT '未开始' COMMENT '任务状态',
    FOREIGN KEY (`project_id`) REFERENCES `projects`(`project_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`researcher_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='项目任务分配表';

-- 2.4 经费报销表
CREATE TABLE `reimbursements` (
    `reimb_id` INT AUTO_INCREMENT PRIMARY KEY COMMENT '报销单号',
    `project_id` INT COMMENT '所属项目ID',
    `applicant_id` INT COMMENT '申请报销的科研人员ID',
    `amount` DECIMAL(10, 2) NOT NULL COMMENT '报销金额',
    `reason` VARCHAR(255) NOT NULL COMMENT '报销事由',
    `apply_date` DATE COMMENT '申请日期',
    `status` ENUM('待审核', '已通过', '已驳回') DEFAULT '待审核' COMMENT '审核状态',
    FOREIGN KEY (`project_id`) REFERENCES `projects`(`project_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`applicant_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='经费报销记录表';

-- 2.5 成果表
CREATE TABLE `achievements` (
    `achievement_id` INT AUTO_INCREMENT PRIMARY KEY COMMENT '成果唯一编号',
    `project_id` INT COMMENT '所属项目ID',
    `submitter_id` INT COMMENT '提交成果的科研人员ID',
    `title` VARCHAR(255) NOT NULL COMMENT '成果名称',
    `type` ENUM('学术论文', '发明专利', '软件著作权', '科技专著', '其他') NOT NULL COMMENT '成果类型',
    `publish_date` DATE COMMENT '获得或发表日期',
    `status` ENUM('待审核', '已通过', '已驳回') DEFAULT '待审核' COMMENT '审核状态',
    FOREIGN KEY (`project_id`) REFERENCES `projects`(`project_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`submitter_id`) REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='科研成果表';

-- 3.1 users表索引
CREATE UNIQUE INDEX idx_username ON users(username);
CREATE INDEX idx_role ON users(role);
CREATE INDEX idx_dept_role ON users(department, role);

-- 3.2 projects表索引
CREATE INDEX idx_status ON projects(status);
CREATE INDEX idx_leader_status ON projects(leader_id, status);
CREATE INDEX idx_applydate_status ON projects(apply_date, status);

-- 3.3 tasks表索引
CREATE INDEX idx_project_status ON tasks(project_id, status);
CREATE INDEX idx_researcher_status ON tasks(researcher_id, status);
CREATE INDEX idx_deadline_status ON tasks(deadline, status);

-- 3.4 reimbursements表索引
CREATE INDEX idx_reimb_project_status ON reimbursements(project_id, status);
CREATE INDEX idx_reimb_applicant_status ON reimbursements(applicant_id, status);
CREATE INDEX idx_reimb_applydate_status ON reimbursements(apply_date, status);

-- 3.5 achievements表索引
CREATE INDEX idx_achievement_project_status ON achievements(project_id, status);
CREATE INDEX idx_achievement_submitter_status ON achievements(submitter_id, status);
CREATE INDEX idx_achievement_type_status ON achievements(type, status);
CREATE INDEX idx_publish_date ON achievements(publish_date);

-- 4.1 科研人员视图
CREATE VIEW `v_researcher_tasks` AS
SELECT 
    t.task_id,
    t.project_id,
    t.researcher_id,
    p.project_name,
    t.task_content,
    t.deadline,
    t.status
FROM tasks t
LEFT JOIN projects p ON t.project_id = p.project_id;

CREATE VIEW `v_researcher_projects` AS
SELECT DISTINCT
    p.project_id,
    p.project_name,
    p.description,
    p.budget,
    p.status,
    p.apply_date
FROM projects p
INNER JOIN tasks t ON p.project_id = t.project_id;

CREATE VIEW `v_researcher_reimbursements` AS
SELECT 
    r.reimb_id,
    r.project_id,
    r.applicant_id,
    p.project_name,
    r.amount,
    r.reason,
    r.apply_date,
    r.status
FROM reimbursements r
LEFT JOIN projects p ON r.project_id = p.project_id;

CREATE VIEW `v_researcher_achievements` AS
SELECT 
    a.achievement_id,
    a.project_id,
    a.submitter_id,
    p.project_name,
    a.title,
    a.type,
    a.publish_date,
    a.status
FROM achievements a
LEFT JOIN projects p ON a.project_id = p.project_id;

-- 4.2 项目负责人视图
CREATE VIEW `v_leader_projects` AS
SELECT 
    p.project_id,
    p.project_name,
    p.description,
    p.budget,
    p.status,
    p.apply_date,
    p.leader_id,
    u.real_name as leader_name
FROM projects p
LEFT JOIN users u ON p.leader_id = u.user_id;

CREATE VIEW `v_researchers` AS
SELECT 
    user_id,
    real_name,
    department
FROM users
WHERE role = '科研人员';

CREATE VIEW `v_project_tasks` AS
SELECT 
    t.task_id,
    t.project_id,
    p.project_name,
    t.researcher_id,
    u.real_name as researcher_name,
    t.task_content,
    t.deadline,
    t.status
FROM tasks t
LEFT JOIN projects p ON t.project_id = p.project_id
LEFT JOIN users u ON t.researcher_id = u.user_id;

CREATE VIEW `v_project_reimbursements` AS
SELECT 
    r.reimb_id,
    r.project_id,
    p.project_name,
    r.applicant_id,
    u.real_name as applicant_name,
    r.amount,
    r.reason,
    r.apply_date,
    r.status
FROM reimbursements r
LEFT JOIN projects p ON r.project_id = p.project_id
LEFT JOIN users u ON r.applicant_id = u.user_id;

CREATE VIEW `v_project_achievements` AS
SELECT 
    a.achievement_id,
    a.project_id,
    p.project_name,
    a.submitter_id,
    u.real_name as submitter_name,
    a.title,
    a.type,
    a.publish_date,
    a.status
FROM achievements a
LEFT JOIN projects p ON a.project_id = p.project_id
LEFT JOIN users u ON a.submitter_id = u.user_id;

CREATE VIEW `v_leader_pending_reimbursements` AS
SELECT 
    r.reimb_id,
    r.project_id,
    p.project_name,
    r.applicant_id,
    u.real_name as applicant_name,
    r.amount,
    r.reason,
    r.apply_date,
    r.status
FROM reimbursements r
LEFT JOIN projects p ON r.project_id = p.project_id
LEFT JOIN users u ON r.applicant_id = u.user_id
WHERE r.status = '待审核'
AND p.leader_id = (SELECT leader_id FROM projects WHERE project_id = r.project_id);

CREATE VIEW `v_leader_pending_achievements` AS
SELECT 
    a.achievement_id,
    a.project_id,
    p.project_name,
    a.submitter_id,
    u.real_name as submitter_name,
    a.title,
    a.type,
    a.publish_date,
    a.status
FROM achievements a
LEFT JOIN projects p ON a.project_id = p.project_id
LEFT JOIN users u ON a.submitter_id = u.user_id
WHERE a.status = '待审核'
AND p.leader_id = (SELECT leader_id FROM projects WHERE project_id = a.project_id);

CREATE VIEW `v_project_researchers_tasks` AS
SELECT 
    u.user_id,
    u.real_name,
    u.department,
    GROUP_CONCAT(CONCAT(t.task_id, '|', t.task_content, '|', t.deadline, '|', t.status) 
                 ORDER BY t.task_id SEPARATOR '||') as task_list
FROM users u
LEFT JOIN tasks t ON u.user_id = t.researcher_id
WHERE u.role = '科研人员'
GROUP BY u.user_id, u.real_name, u.department
HAVING task_list IS NOT NULL;

-- 4.3 管理员视图
CREATE VIEW `v_admin_projects` AS
SELECT 
    p.project_id,
    p.project_name,
    p.description,
    p.budget,
    p.status,
    p.apply_date,
    u.real_name as leader_name,
    u.user_id as leader_id,
    (SELECT COUNT(*) FROM tasks WHERE project_id = p.project_id) as task_count,
    (SELECT COUNT(*) FROM tasks WHERE project_id = p.project_id AND status = '已完成') as completed_task_count,
    (SELECT COUNT(*) FROM reimbursements WHERE project_id = p.project_id) as reimbursement_count,
    (SELECT SUM(amount) FROM reimbursements WHERE project_id = p.project_id AND status = '已通过') as total_reimbursement,
    (SELECT COUNT(*) FROM achievements WHERE project_id = p.project_id) as achievement_count,
    (SELECT COUNT(*) FROM achievements WHERE project_id = p.project_id AND status = '已通过') as approved_achievement_count
FROM projects p
LEFT JOIN users u ON p.leader_id = u.user_id;

CREATE VIEW `v_all_users` AS
SELECT 
    u.user_id,
    u.username,
    u.real_name,
    u.role,
    u.department,
    (SELECT COUNT(*) FROM tasks WHERE researcher_id = u.user_id) as task_count,
    (SELECT COUNT(*) FROM tasks WHERE researcher_id = u.user_id AND status = '已完成') as completed_task_count,
    (SELECT COUNT(*) FROM achievements WHERE submitter_id = u.user_id) as achievement_count,
    (SELECT COUNT(*) FROM achievements WHERE submitter_id = u.user_id AND status = '已通过') as approved_achievement_count,
    (SELECT COUNT(*) FROM projects WHERE leader_id = u.user_id) as led_project_count,
    (SELECT COUNT(*) FROM projects WHERE leader_id = u.user_id AND status = '已结题') as completed_project_count
FROM users u;

CREATE VIEW `v_admin_statistics` AS
SELECT 
    (SELECT COUNT(*) FROM projects) as total_projects,
    (SELECT COUNT(*) FROM projects WHERE status = '申报中') as applying_projects,
    (SELECT COUNT(*) FROM projects WHERE status = '执行中') as executing_projects,
    (SELECT COUNT(*) FROM projects WHERE status = '已结题') as completed_projects,
    (SELECT COUNT(*) FROM users WHERE role = '科研人员') as total_researchers,
    (SELECT COUNT(*) FROM users WHERE role = '项目负责人') as total_leaders,
    (SELECT SUM(budget) FROM projects) as total_budget,
    (SELECT SUM(amount) FROM reimbursements WHERE status = '已通过') as total_reimbursed,
    (SELECT COUNT(*) FROM achievements WHERE status = '已通过') as total_achievements;

CREATE VIEW `v_admin_reimbursements` AS
SELECT 
    r.reimb_id,
    r.project_id,
    p.project_name,
    r.applicant_id,
    u.real_name as applicant_name,
    r.amount,
    r.reason,
    r.apply_date,
    r.status
FROM reimbursements r
LEFT JOIN projects p ON r.project_id = p.project_id
LEFT JOIN users u ON r.applicant_id = u.user_id
ORDER BY r.apply_date DESC;

CREATE VIEW `v_admin_achievements` AS
SELECT 
    a.achievement_id,
    a.project_id,
    p.project_name,
    a.submitter_id,
    u.real_name as submitter_name,
    a.title,
    a.type,
    a.publish_date,
    a.status
FROM achievements a
LEFT JOIN projects p ON a.project_id = p.project_id
LEFT JOIN users u ON a.submitter_id = u.user_id
ORDER BY a.publish_date DESC;

-- 5.1 项目状态变更触发器 - 已删除，因为现在要求所有任务完成后才能结题，不需要自动完成任务的触发器

-- 5.2 报销申请预算校验触发器 - 已删除，改为在存储过程中检查预算

-- 5.3 报销审核预算校验触发器 - 审核通过时再次检查预算
DELIMITER //
CREATE TRIGGER trg_reimbursement_approve_check
BEFORE UPDATE ON reimbursements
FOR EACH ROW
BEGIN
    DECLARE project_budget DECIMAL(10,2);
    DECLARE total_reimbursed DECIMAL(10,2);
    
    IF NEW.status = '已通过' AND OLD.status != '已通过' THEN
        SELECT budget INTO project_budget
        FROM projects
        WHERE project_id = NEW.project_id;
        
        SELECT IFNULL(SUM(amount), 0) INTO total_reimbursed
        FROM reimbursements
        WHERE project_id = NEW.project_id
        AND status = '已通过'
        AND reimb_id != NEW.reimb_id;
        
        IF (total_reimbursed + NEW.amount) > project_budget THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '报销金额超出项目预算！';
        END IF;
    END IF;
END //
DELIMITER ;

-- 5.4 成果审核通过触发器 - 已删除，不再自动设置发表日期

-- 5.5 用户删除保护触发器
DELIMITER //
CREATE TRIGGER trg_user_delete_protect
BEFORE DELETE ON users
FOR EACH ROW
BEGIN
    DECLARE project_count INT;
    DECLARE task_count INT;
    
    SELECT COUNT(*) INTO project_count
    FROM projects
    WHERE leader_id = OLD.user_id
    AND status != '已结题';
    
    SELECT COUNT(*) INTO task_count
    FROM tasks
    WHERE researcher_id = OLD.user_id
    AND status IN ('未开始', '进行中');
    
    IF project_count > 0 OR task_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '该用户仍有未结题项目或未完成任务，无法删除！';
    END IF;
END //
DELIMITER ;

-- 6.1 项目申报审核存储过程
DELIMITER //
CREATE PROCEDURE sp_review_project(
    IN p_project_id INT,
    IN p_action VARCHAR(20),
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE current_status VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = '操作失败，请重试！';
    END;
    
    START TRANSACTION;
    
    SELECT status INTO current_status
    FROM projects
    WHERE project_id = p_project_id;
    
    IF current_status = '申报中' THEN
        IF p_action = 'APPROVE' THEN
            UPDATE projects
            SET status = '执行中'
            WHERE project_id = p_project_id;
            SET p_result = '项目审核通过，已立项执行！';
        ELSEIF p_action = 'REJECT' THEN
            UPDATE projects
            SET status = '已驳回'
            WHERE project_id = p_project_id;
            SET p_result = '项目审核驳回，请修改后重新提交！';
        ELSE
            SET p_result = '操作失败！无效的操作指令，请使用 APPROVE 或 REJECT';
            ROLLBACK;
        END IF;
        COMMIT;
    ELSE
        SET p_result = CONCAT('操作失败！项目当前状态为"', current_status, '"，无法进行审核');
        ROLLBACK;
    END IF;
END //
DELIMITER ;

-- 6.2 任务分配存储过程
DELIMITER //
CREATE PROCEDURE sp_assign_task(
    IN p_project_id INT,
    IN p_researcher_id INT,
    IN p_task_content TEXT,
    IN p_deadline DATE,
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE project_status VARCHAR(20);
    DECLARE researcher_role VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = '任务分配失败，请重试！';
    END;
    
    START TRANSACTION;
    
    SELECT status INTO project_status
    FROM projects
    WHERE project_id = p_project_id;
    
    SELECT role INTO researcher_role
    FROM users
    WHERE user_id = p_researcher_id;
    
    IF project_status != '执行中' THEN
        SET p_result = CONCAT('任务分配失败！项目状态为"', project_status, '"，仅执行中项目可分配任务');
        ROLLBACK;
    ELSEIF researcher_role != '科研人员' THEN
        SET p_result = CONCAT('任务分配失败！用户角色为"', researcher_role, '"，仅科研人员可接受任务分配');
        ROLLBACK;
    ELSE
        INSERT INTO tasks (project_id, researcher_id, task_content, deadline, status)
        VALUES (p_project_id, p_researcher_id, p_task_content, p_deadline, '未开始');
        SET p_result = '任务分配成功！';
        COMMIT;
    END IF;
END //
DELIMITER ;

-- 6.3 报销审核存储过程
DELIMITER //
CREATE PROCEDURE sp_review_reimbursement(
    IN p_reimb_id INT,
    IN p_action VARCHAR(10),
    OUT p_result VARCHAR(100),
    OUT p_project_id INT
)
BEGIN
    DECLARE current_status VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = '审核操作失败，请检查剩余额度！';
        SET p_project_id = NULL;
    END;
    
    START TRANSACTION;
    
    SELECT status, project_id INTO current_status, p_project_id
    FROM reimbursements
    WHERE reimb_id = p_reimb_id;
    
    IF current_status != '待审核' THEN
        SET p_result = CONCAT('审核失败！报销单状态为"', current_status, '"，无法重复审核');
        ROLLBACK;
    ELSE
        IF p_action = 'APPROVE' THEN
            UPDATE reimbursements
            SET status = '已通过'
            WHERE reimb_id = p_reimb_id;
            SET p_result = '报销审核通过！';
            COMMIT;
        ELSEIF p_action = 'REJECT' THEN
            UPDATE reimbursements
            SET status = '已驳回'
            WHERE reimb_id = p_reimb_id;
            SET p_result = '报销审核驳回！';
            COMMIT;
        ELSE
            SET p_result = '操作失败！无效的操作指令，请使用 APPROVE 或 REJECT';
            ROLLBACK;
        END IF;
    END IF;
END //
DELIMITER ;

-- 6.4 提交成果存储过程
DELIMITER //
CREATE PROCEDURE sp_submit_achievement_new(
    IN p_project_id INT,
    IN p_submitter_id INT,
    IN p_title VARCHAR(255),
    IN p_type VARCHAR(20),
    IN p_publish_date DATE,
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE project_status VARCHAR(20);
    DECLARE submitter_role VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = '操作失败，请重试！';
    END;
    
    START TRANSACTION;
    
    SELECT status INTO project_status
    FROM projects
    WHERE project_id = p_project_id;
    
    SELECT role INTO submitter_role
    FROM users
    WHERE user_id = p_submitter_id;
    
    IF project_status != '执行中' THEN
        SET p_result = '提交失败！项目未处于执行状态';
        ROLLBACK;
    ELSEIF submitter_role != '科研人员' THEN
        SET p_result = '提交失败！只有科研人员可以提交成果';
        ROLLBACK;
    ELSE
        INSERT INTO achievements (project_id, submitter_id, title, type, publish_date, status)
        VALUES (p_project_id, p_submitter_id, p_title, p_type, p_publish_date, '待审核');
        SET p_result = '成果提交成功！';
        COMMIT;
    END IF;
END //
DELIMITER ;

-- 6.5 申请报销存储过程（包含预算检查）
DELIMITER //
CREATE PROCEDURE sp_apply_reimbursement_new(
    IN p_project_id INT,
    IN p_applicant_id INT,
    IN p_amount DECIMAL(10,2),
    IN p_reason TEXT,
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE project_status VARCHAR(20);
    DECLARE applicant_role VARCHAR(20);
    DECLARE project_budget DECIMAL(10,2);
    DECLARE total_reimbursed DECIMAL(10,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = '操作失败，请重试！';
    END;
    
    START TRANSACTION;
    
    SELECT status INTO project_status
    FROM projects
    WHERE project_id = p_project_id;
    
    SELECT role INTO applicant_role
    FROM users
    WHERE user_id = p_applicant_id;
    
    IF project_status != '执行中' THEN
        SET p_result = '申请失败！项目未处于执行状态';
        ROLLBACK;
    ELSEIF applicant_role != '科研人员' THEN
        SET p_result = '申请失败！只有科研人员可以申请报销';
        ROLLBACK;
    ELSE
        SELECT budget INTO project_budget
        FROM projects
        WHERE project_id = p_project_id;
        
        SELECT IFNULL(SUM(amount), 0) INTO total_reimbursed
        FROM reimbursements
        WHERE project_id = p_project_id
        AND status = '已通过';
        
        IF (total_reimbursed + p_amount) > project_budget THEN
            SET p_result = CONCAT('报销金额超出项目剩余预算！剩余预算：', (project_budget - total_reimbursed), '元');
            ROLLBACK;
        ELSE
            INSERT INTO reimbursements (project_id, applicant_id, amount, reason, apply_date, status)
            VALUES (p_project_id, p_applicant_id, p_amount, p_reason, CURDATE(), '待审核');
            SET p_result = '报销申请提交成功！';
            COMMIT;
        END IF;
    END IF;
END //
DELIMITER ;

-- 6.6 更新项目信息存储过程
DELIMITER //
CREATE PROCEDURE sp_update_project(
    IN p_project_id INT,
    IN p_project_name VARCHAR(255),
    IN p_description TEXT,
    IN p_budget DECIMAL(10,2),
    IN p_leader_id INT,
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE current_status VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = '操作失败，请重试！';
    END;
    
    START TRANSACTION;
    
    SELECT status INTO current_status
    FROM projects
    WHERE project_id = p_project_id AND leader_id = p_leader_id;
    
    IF current_status = '已驳回' THEN
        UPDATE projects
        SET project_name = p_project_name, description = p_description, budget = p_budget, status = '申报中'
        WHERE project_id = p_project_id;
        SET p_result = '项目信息已更新并重新提交申报成功！';
        COMMIT;
    ELSE
        SET p_result = '操作失败！只有已驳回的项目可以修改';
        ROLLBACK;
    END IF;
END //
DELIMITER ;

-- 6.7 申请结题存储过程
DELIMITER //
CREATE PROCEDURE sp_request_complete(
    IN p_project_id INT,
    IN p_leader_id INT,
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE current_status VARCHAR(20);
    DECLARE unfinished_task_count INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = '操作失败，请重试！';
    END;
    
    START TRANSACTION;
    
    SELECT status INTO current_status
    FROM projects
    WHERE project_id = p_project_id AND leader_id = p_leader_id;
    
    IF current_status = '执行中' THEN
        SELECT COUNT(*) INTO unfinished_task_count
        FROM tasks
        WHERE project_id = p_project_id
        AND status IN ('未开始', '进行中');
        
        IF unfinished_task_count > 0 THEN
            SET p_result = CONCAT('结题失败！该项目还有 ', unfinished_task_count, ' 个未完成的任务，请先完成所有任务后再申请结题');
            ROLLBACK;
        ELSE
            UPDATE projects
            SET status = '已结题'
            WHERE project_id = p_project_id;
            SET p_result = '项目已结题！';
            COMMIT;
        END IF;
    ELSE
        SET p_result = CONCAT('操作失败！项目当前状态为"', current_status, '"，无法结题');
        ROLLBACK;
    END IF;
END //
DELIMITER ;

-- 6.8 添加用户存储过程
DELIMITER //
CREATE PROCEDURE sp_add_user(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(32),
    IN p_real_name VARCHAR(50),
    IN p_role VARCHAR(20),
    IN p_department VARCHAR(100),
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = '操作失败，请重试！';
    END;
    
    START TRANSACTION;
    
    INSERT INTO users (username, password, real_name, role, department)
    VALUES (p_username, p_password, p_real_name, p_role, p_department);
    
    SET p_result = '用户添加成功！';
    COMMIT;
END //
DELIMITER ;

-- 6.9 删除用户存储过程
DELIMITER //
CREATE PROCEDURE sp_delete_user(
    IN p_user_id INT,
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = '操作失败，请重试！';
    END;
    
    START TRANSACTION;
    
    DELETE FROM users WHERE user_id = p_user_id;
    
    SET p_result = '用户删除成功！';
    COMMIT;
END //
DELIMITER ;

-- 6.10 审核成果存储过程
DELIMITER //
CREATE PROCEDURE sp_review_achievement(
    IN p_achievement_id INT,
    IN p_action VARCHAR(20),
    OUT p_result VARCHAR(100),
    OUT p_project_id INT
)
BEGIN
    DECLARE current_status VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = '操作失败，请重试！';
        SET p_project_id = NULL;
    END;
    
    START TRANSACTION;
    
    SELECT status, project_id INTO current_status, p_project_id
    FROM achievements
    WHERE achievement_id = p_achievement_id;
    
    IF current_status = '待审核' THEN
        IF p_action = 'APPROVE' THEN
            UPDATE achievements
            SET status = '已通过'
            WHERE achievement_id = p_achievement_id;
            SET p_result = '成果审核通过！';
            COMMIT;
        ELSEIF p_action = 'REJECT' THEN
            UPDATE achievements
            SET status = '已驳回'
            WHERE achievement_id = p_achievement_id;
            SET p_result = '成果审核驳回！';
            COMMIT;
        ELSE
            SET p_result = '操作失败！无效的操作指令，请使用 APPROVE 或 REJECT';
            ROLLBACK;
        END IF;
    ELSE
        SET p_result = CONCAT('操作失败！成果当前状态为"', current_status, '"，无法重复审核');
        ROLLBACK;
    END IF;
END //
DELIMITER ;

-- 6.11 更新任务状态存储过程
DELIMITER //
CREATE PROCEDURE sp_update_task(
    IN p_task_id INT,
    IN p_status VARCHAR(20),
    IN p_researcher_id INT,
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE current_researcher_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = '操作失败，请重试！';
    END;
    
    START TRANSACTION;
    
    SELECT researcher_id INTO current_researcher_id
    FROM tasks
    WHERE task_id = p_task_id;
    
    IF current_researcher_id != p_researcher_id THEN
        SET p_result = '操作失败！您无权修改此任务状态';
        ROLLBACK;
    ELSE
        UPDATE tasks
        SET status = p_status
        WHERE task_id = p_task_id;
        SET p_result = '任务状态更新成功！';
        COMMIT;
    END IF;
END //
DELIMITER ;

-- 6.12 添加项目存储过程
DELIMITER //
CREATE PROCEDURE sp_add_project(
    IN p_project_name VARCHAR(255),
    IN p_description TEXT,
    IN p_budget DECIMAL(10,2),
    IN p_leader_id INT,
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = '操作失败，请重试！';
    END;
    
    START TRANSACTION;
    
    INSERT INTO projects (project_name, description, budget, leader_id, apply_date, status)
    VALUES (p_project_name, p_description, p_budget, p_leader_id, CURDATE(), '申报中');
    
    SET p_result = '项目申报成功！';
    COMMIT;
END //
DELIMITER ;

-- 6.13 更新用户角色存储过程
DELIMITER //
CREATE PROCEDURE sp_update_user_role(
    IN p_user_id INT,
    IN p_new_role VARCHAR(20),
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE current_role VARCHAR(20);
    DECLARE project_count INT;
    DECLARE task_count INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = '操作失败，请重试！';
    END;
    
    START TRANSACTION;
    
    SELECT role INTO current_role
    FROM users
    WHERE user_id = p_user_id;
    
    IF current_role = p_new_role THEN
        SET p_result = '用户角色未改变';
        ROLLBACK;
    ELSEIF current_role = '科研机构管理员' THEN
        SET p_result = '无法修改管理员角色';
        ROLLBACK;
    ELSEIF p_new_role = '科研机构管理员' THEN
        SET p_result = '无法设置为管理员角色';
        ROLLBACK;
    ELSE
        IF p_new_role = '科研人员' AND current_role = '项目负责人' THEN
            SELECT COUNT(*) INTO project_count
            FROM projects
            WHERE leader_id = p_user_id
            AND status != '已结题';
            
            IF project_count > 0 THEN
                SET p_result = CONCAT('该用户还有 ', project_count, ' 个未结题项目，无法降级为科研人员');
                ROLLBACK;
            ELSE
                UPDATE users
                SET role = p_new_role
                WHERE user_id = p_user_id;
                SET p_result = '用户角色更新成功！';
                COMMIT;
            END IF;
        ELSE
            UPDATE users
            SET role = p_new_role
            WHERE user_id = p_user_id;
            SET p_result = '用户角色更新成功！';
            COMMIT;
        END IF;
    END IF;
END //
DELIMITER ;

-- 7.1 插入测试用户数据
INSERT INTO `users` (`username`, `password`, `real_name`, `role`, `department`) VALUES
('admin', MD5('123456'), '系统管理员', '科研机构管理员', '科研处'),
('user1', MD5('123456'), 'user1', '项目负责人', 'user1'),
('user2', MD5('123456'), 'user2', '科研人员', 'user2'),
('user3', MD5('123456'), 'user3', '科研人员', 'user3');