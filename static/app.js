// 当前选中的tab和数据类型
let currentTab = 'crew';
let currentData = [];
let editingId = null;
let schoolNames = []; // 学校名称列表
let shipNames = [];   // 船舶名称列表
let companyNames = []; // 船公司名称列表
let managementNames = []; // 管理公司名称列表

// 统一处理“拥有/管理船舶”字段的取值与展示（兼容不同接口/数据结构）
function getShipsLikeValue(item) {
    if (!item || typeof item !== 'object') return undefined;
    // 兼容：不同后端/序列化可能使用不同字段名
    return (
        item.ships ??
        item.Ships ??
        item.managed_ships ??
        item.managedShips ??
        item.ship_names ??
        item.shipNames ??
        item.vessels ??
        item.Vessels
    );
}

function normalizeShipList(val) {
    if (val === undefined || val === null || val === '') return [];

    // 字符串：支持“逗号分隔”
    if (typeof val === 'string') {
        return val
            .split(',')
            .map(s => s.trim())
            .filter(Boolean);
    }

    // 数组：支持 string[] 或 object[]（{name: "..."}）
    if (Array.isArray(val)) {
        return val
            .map(v => {
                if (v === undefined || v === null) return '';
                if (typeof v === 'string') return v.trim();
                if (typeof v === 'object') {
                    if (typeof v.name === 'string') return v.name.trim();
                    if (typeof v.ship_name === 'string') return v.ship_name.trim();
                    if (typeof v.shipName === 'string') return v.shipName.trim();
                }
                return String(v).trim();
            })
            .filter(Boolean);
    }

    // 单个对象：尽量提取 name
    if (typeof val === 'object') {
        if (typeof val.name === 'string') return [val.name.trim()];
        return [String(val).trim()].filter(Boolean);
    }

    return [String(val).trim()].filter(Boolean);
}

function formatShipListForTable(val) {
    const list = normalizeShipList(val);
    if (list.length === 0) return '-';
    let text = list.join(', ');
    if (text.length > 50) text = text.substring(0, 50) + '...';
    return text;
}

function formatShipListForDetail(val) {
    const list = normalizeShipList(val);
    return list.length === 0 ? '-' : list.join(', ');
}

// Tab配置 - 定义每个tab的字段和API端点
const tabConfig = {
    crew: {
        name: '船员',
        api: '/api/crew',
        fields: [
            { key: 'name', label: '姓名', type: 'text' },
            { key: 'region', label: '地区', type: 'text' },
            { key: 'birth_date', label: '出生年月', type: 'text' },
            { key: 'education', label: '学历', type: 'text' },
            { key: 'graduation_school', label: '毕业学校', type: 'select', relation: 'school' },
            { key: 'status', label: '状态', type: 'select', options: ['在船', '休假', '学习'] },
            { key: 'position', label: '职务', type: 'text' },
            { key: 'current_ship', label: '现就职船舶', type: 'select', relation: 'ship' },
            { key: 'phone', label: '电话', type: 'text' },
            { key: 'height', label: '身高(cm)', type: 'number' },
            { key: 'weight', label: '体重(kg)', type: 'number' },
            { key: 'experience', label: '资历', type: 'textarea' },
            { key: 'is_professional', label: '是否科班', type: 'checkbox' },
            { key: 'colleague_evaluation', label: '同事评价', type: 'textarea' },
            { key: 'company_evaluation', label: '公司评价', type: 'textarea' },
            { key: 'remark', label: '备注', type: 'textarea' }
        ],
        tableColumns: ['ID', '姓名', '地区', '出生年月', '学历', '状态', '职务', '电话', '操作']
    },
    ship: {
        name: '船舶',
        api: '/api/ship',
        fields: [
            { key: 'name', label: '船名', type: 'text' },
            { key: 'build_date', label: '建造年月', type: 'text' },
            { key: 'ship_class', label: '船级', type: 'text' },
            { key: 'owner_company', label: '所属公司', type: 'select', relation: 'company' },
            { key: 'crew_company', label: '派员公司', type: 'select', relation: 'management' },
            { key: 'engine_model', label: '主机型号', type: 'text' },
            { key: 'power', label: '功率', type: 'text' },
            { key: 'gross_tonnage', label: '总吨', type: 'text' },
            { key: 'deadweight_tonnage', label: '载重吨', type: 'text' },
            { key: 'port_of_registry', label: '船籍港', type: 'text' },
            { key: 'ship_condition', label: '船况', type: 'text' },
            { key: 'salary_status', label: '工资发放情况', type: 'text' },
            { key: 'living_expense', label: '生活费', type: 'text' },
            { key: 'has_pension', label: '是否养老', type: 'checkbox' },
            { key: 'can_open_seal', label: '能否开封', type: 'checkbox' },
            { key: 'personnel_phone', label: '人事电话', type: 'text' },
            { key: 'company_type', label: '公司属性', type: 'select', options: ['国企', '民营', '个人'] },
            { key: 'remark', label: '备注', type: 'textarea' }
        ],
        tableColumns: ['ID', '船名', '建造年月', '船级', '所属公司', '派员公司', '船籍港', '操作']
    },
    school: {
        name: '学校',
        api: '/api/school',
        fields: [
            { key: 'name', label: '名称', type: 'text' },
            { key: 'address', label: '地址', type: 'textarea' },
            { key: 'admission_phone', label: '招生电话', type: 'text' },
            { key: 'level', label: '级别', type: 'text' },
            { key: 'other_info', label: '其他信息', type: 'textarea' }
        ],
        tableColumns: ['ID', '名称', '地址', '招生电话', '级别', '操作']
    },
    company: {
        name: '船公司',
        api: '/api/company',
        fields: [
            { key: 'name', label: '公司名', type: 'text' },
            { key: 'address', label: '地址', type: 'textarea' },
            { key: 'contact_phone', label: '联系电话', type: 'text' },
            { key: 'ships', label: '拥有船舶', type: 'display', isArray: true },
            { key: 'remark', label: '备注', type: 'textarea' }
        ],
        tableColumns: ['ID', '公司名', '地址', '拥有船舶', '联系电话', '操作']
    },
    management: {
        name: '管理公司',
        api: '/api/management',
        fields: [
            { key: 'name', label: '公司名', type: 'text' },
            { key: 'address', label: '地址', type: 'textarea' },
            { key: 'reputation', label: '信誉度', type: 'text' },
            { key: 'salary_status', label: '工资发放情况', type: 'text' },
            { key: 'contact_phone', label: '联系电话', type: 'text' },
            { key: 'ships', label: '管理船舶', type: 'display', isArray: true },
            { key: 'remark', label: '备注', type: 'textarea' }
        ],
        tableColumns: ['ID', '公司名', '地址', '管理船舶', '信誉度', '联系电话', '操作']
    }
};

// 切换Tab
function switchTab(tab) {
    currentTab = tab;
    editingId = null;
    
    // 更新tab样式
    document.querySelectorAll('.tab').forEach((t, index) => {
        const tabs = ['crew', 'ship', 'school', 'company', 'management'];
        if (tabs[index] === tab) {
            t.classList.add('active');
        } else {
            t.classList.remove('active');
        }
    });
    
    // 清空搜索框和筛选条件
    document.getElementById('searchInput').value = '';
    currentFilters = {};
    
    // 加载数据
    loadData();
}

// 加载数据
async function loadData(keyword = '', filters = null) {
    const config = tabConfig[currentTab];
    let url = config.api;
    
    console.log('调试 - loadData 开始:', { currentTab, keyword, filters, url });
    
    // 如果有筛选条件，使用筛选API
    if (filters && Object.keys(filters).length > 0) {
        url += '/filter';
        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(filters)
            });
            const result = await response.json();
            
            console.log('调试 - 筛选API响应:', result);
            
            if (result.success) {
                currentData = result.data || [];
                console.log('调试 - 筛选后数据:', currentData);
                renderTable();
            } else {
                alert('筛选失败: ' + result.message);
            }
            return;
        } catch (error) {
            console.error('Error:', error);
            alert('筛选失败');
            return;
        }
    }
    
    // 如果有关键词，使用搜索API
    if (keyword) {
        url += '/search?keyword=' + encodeURIComponent(keyword);
    }
    
    try {
        const response = await fetch(url);
        const result = await response.json();
        
        console.log('调试 - API响应:', { url, result });
        
        if (result.success) {
            currentData = result.data || [];
            console.log('调试 - 加载后数据:', currentData);
            renderTable();
        } else {
            alert('加载失败: ' + result.message);
        }
    } catch (error) {
        console.error('Error:', error);
        alert('加载数据失败');
    }
}

// 渲染表格
function renderTable() {
    const config = tabConfig[currentTab];
    const thead = document.getElementById('tableHead');
    const tbody = document.getElementById('tableBody');
    const emptyState = document.getElementById('emptyState');
    
    console.log('调试 - renderTable 开始:', { currentTab, dataLength: currentData.length, config });
    
    // 清空表格
    thead.innerHTML = '';
    tbody.innerHTML = '';
    
    if (currentData.length === 0) {
        console.log('调试 - 数据为空，显示空状态');
        emptyState.style.display = 'block';
        return;
    }
    
    emptyState.style.display = 'none';
    
    // 创建表头
    const headerRow = document.createElement('tr');
    config.tableColumns.forEach(col => {
        const th = document.createElement('th');
        th.textContent = col;
        headerRow.appendChild(th);
    });
    thead.appendChild(headerRow);
    
    // 创建数据行
    currentData.forEach((item, itemIndex) => {
        console.log('调试 - 处理数据项:', { itemIndex, item });
        const row = document.createElement('tr');
        
        // 根据配置显示列
        config.tableColumns.forEach((col, colIndex) => {
            if (currentTab === 'management') {
                console.log('调试 - 处理列:', { itemIndex, colIndex, col });
            }
            const td = document.createElement('td');
            
            if (col === '操作') {
                td.className = 'actions';
                td.innerHTML = `
                    <button class="btn btn-primary btn-sm" onclick="viewDetail(${item.id})">查看</button>
                    <button class="btn btn-success btn-sm" onclick="editItem(${item.id})">编辑</button>
                    <button class="btn btn-danger btn-sm" onclick="deleteItem(${item.id})">删除</button>
                `;
            } else if (col === 'ID') {
                td.textContent = item.id;
            } else {
                // 根据列名找到对应的字段
                const fieldMap = {
                    '姓名': 'name',
                    '地区': 'region',
                    '出生年月': 'birth_date',
                    '学历': 'education',
                    '状态': 'status',
                    '职务': 'position',
                    '电话': 'phone',
                    '船名': 'name',
                    '建造年月': 'build_date',
                    '船级': 'ship_class',
                    '所属公司': 'owner_company',
                    '派员公司': 'crew_company',
                    '船籍港': 'port_of_registry',
                    '名称': 'name',
                    '地址': 'address',
                    '招生电话': 'admission_phone',
                    '级别': 'level',
                    '公司名': 'name',
                    '联系电话': 'contact_phone',
                    '信誉度': 'reputation',
                    '拥有船舶': 'ships',
                    '管理船舶': 'ships'
                };
                
                const fieldKey = fieldMap[col];
                if (fieldKey) {
                    // “船舶列表”字段：统一兼容处理（避免管理公司tab取不到或结构不同导致不显示）
                    if (fieldKey === 'ships') {
                        const raw = getShipsLikeValue(item);
                        console.log('调试 - 管理船舶字段:', {
                            col: col,
                            fieldKey: fieldKey,
                            rawValue: raw,
                            item: item,
                            itemShips: item.ships
                        });
                        td.textContent = formatShipListForTable(raw);
                    } else {
                        let value = item[fieldKey];
                        // 如果是数组（普通数组字段）
                        if (Array.isArray(value)) {
                            value = value.length > 0 ? value.join(', ') : '-';
                        }
                        // 如果是布尔值，显示中文
                        else if (typeof value === 'boolean') {
                            value = value ? '是' : '否';
                        }
                        // 如果值不存在或为空字符串
                        else if (value === undefined || value === null || value === '') {
                            value = '-';
                        }
                        // 如果文本太长，截断
                        if (typeof value === 'string' && value.length > 50) {
                            value = value.substring(0, 50) + '...';
                        }
                        td.textContent = value;
                    }
                } else {
                    td.textContent = '-';
                }
            }
            
            row.appendChild(td);
        });
        
        tbody.appendChild(row);
    });
}

// 显示添加模态框
function showAddModal() {
    editingId = null;
    showFormModal();
}

// 显示编辑模态框
function editItem(id) {
    editingId = id;
    const item = currentData.find(d => d.id === id);
    if (!item) {
        alert('记录不存在');
        return;
    }
    showFormModal(item);
}

// 加载关联数据
async function loadRelationData() {
    try {
        // 加载学校名称列表
        const schoolResponse = await fetch('/api/schools/names');
        const schoolResult = await schoolResponse.json();
        if (schoolResult.success) {
            schoolNames = schoolResult.data || [];
        }
        
        // 加载船舶名称列表
        const shipResponse = await fetch('/api/ships/names');
        const shipResult = await shipResponse.json();
        if (shipResult.success) {
            shipNames = shipResult.data || [];
        }
        
        // 加载船公司名称列表
        const companyResponse = await fetch('/api/companies/names');
        const companyResult = await companyResponse.json();
        if (companyResult.success) {
            companyNames = companyResult.data || [];
        }
        
        // 加载管理公司名称列表
        const managementResponse = await fetch('/api/managements/names');
        const managementResult = await managementResponse.json();
        if (managementResult.success) {
            managementNames = managementResult.data || [];
        }
    } catch (error) {
        console.error('加载关联数据失败:', error);
    }
}

// 显示表单模态框
async function showFormModal(data = null) {
    const config = tabConfig[currentTab];
    const modal = document.getElementById('formModal');
    const form = document.getElementById('dataForm');
    const title = document.getElementById('modalTitle');
    
    title.textContent = data ? '编辑' + config.name : '添加' + config.name;
    
    // 加载关联数据
    await loadRelationData();
    
    // 生成表单
    form.innerHTML = '';
    
    // 过滤掉 ships 字段和 display 类型的字段，确保它们不会出现在表单中
    const formFields = config.fields.filter(field => {
        // 跳过 display 类型的字段
        if (field.type === 'display') {
            console.log('跳过 display 字段:', field.key);
            return false;
        }
        // 明确跳过 ships 字段（船公司和管理公司的船舶字段，由船舶表绑定，不需要在表单中选择）
        if (field.key === 'ships') {
            console.log('跳过 ships 字段:', field.key, field.label);
            return false;
        }
        return true;
    });
    
    console.log('表单字段列表:', formFields.map(f => ({ key: f.key, label: f.label, type: f.type })));
    
    formFields.forEach(field => {
        
        const group = document.createElement('div');
        group.className = 'form-group';
        
        const label = document.createElement('label');
        label.textContent = field.label;
        label.setAttribute('for', field.key);
        
        let input;
        if (field.type === 'select') {
            // 根据关联类型或静态选项加载选项
            let options = [];
            if (field.options) {
                // 静态选项（如：公司属性的选项）
                options = field.options.map(opt => ({ id: opt, name: opt }));
            } else if (field.relation === 'school') {
                options = schoolNames;
            } else if (field.relation === 'ship') {
                options = shipNames;
            } else if (field.relation === 'company') {
                options = companyNames;
            } else if (field.relation === 'management') {
                options = managementNames;
            }
            
            // 多选模式：使用复选框列表
            if (field.multiple) {
                // 创建复选框容器
                const checkboxContainer = document.createElement('div');
                checkboxContainer.className = 'checkbox-group';
                checkboxContainer.id = field.key + '_container';
                
                // 处理已选中的值（如果是字符串，需要分割）
                let selectedValues = [];
                if (data && data[field.key]) {
                    selectedValues = typeof data[field.key] === 'string' 
                        ? data[field.key].split(',').map(v => v.trim()).filter(v => v)
                        : Array.isArray(data[field.key]) ? data[field.key] : [];
                }
                
                // 为每个选项创建复选框
                options.forEach(option => {
                    const checkboxWrapper = document.createElement('div');
                    checkboxWrapper.className = 'checkbox-item';
                    
                    const checkbox = document.createElement('input');
                    checkbox.type = 'checkbox';
                    checkbox.id = field.key + '_' + option.id;
                    checkbox.name = field.key;
                    checkbox.value = option.name;
                    checkbox.checked = selectedValues.includes(option.name);
                    
                    const checkboxLabel = document.createElement('label');
                    checkboxLabel.setAttribute('for', field.key + '_' + option.id);
                    checkboxLabel.textContent = option.name;
                    
                    checkboxWrapper.appendChild(checkbox);
                    checkboxWrapper.appendChild(checkboxLabel);
                    checkboxContainer.appendChild(checkboxWrapper);
                });
                
                input = checkboxContainer;
            } else {
                // 单选模式：使用下拉框
                input = document.createElement('select');
                input.id = field.key;
                input.name = field.key;
                
                // 添加空选项
                const emptyOption = document.createElement('option');
                emptyOption.value = '';
                emptyOption.textContent = '请选择...';
                input.appendChild(emptyOption);
                
                // 添加所有选项
                options.forEach(option => {
                    const opt = document.createElement('option');
                    opt.value = option.name;
                    opt.textContent = option.name;
                    input.appendChild(opt);
                });
                
                // 设置选中值
                if (data && data[field.key]) {
                    input.value = data[field.key];
                }
            }
        } else if (field.type === 'textarea') {
            input = document.createElement('textarea');
            input.id = field.key;
            input.name = field.key;
            if (data) input.value = data[field.key] || '';
        } else if (field.type === 'checkbox') {
            input = document.createElement('input');
            input.type = 'checkbox';
            input.id = field.key;
            input.name = field.key;
            if (data) input.checked = data[field.key] || false;
        } else {
            input = document.createElement('input');
            input.type = field.type;
            input.id = field.key;
            input.name = field.key;
            if (data) input.value = data[field.key] || '';
        }
        
        group.appendChild(label);
        group.appendChild(input);
        form.appendChild(group);
    });
    
    // 添加提交按钮
    const submitBtn = document.createElement('button');
    submitBtn.type = 'button';
    submitBtn.className = 'btn btn-primary';
    submitBtn.textContent = '保存';
    submitBtn.onclick = saveData;
    form.appendChild(submitBtn);
    
    modal.style.display = 'block';
}

// 保存数据
async function saveData() {
    const config = tabConfig[currentTab];
    const form = document.getElementById('dataForm');
    const formData = new FormData(form);
    
    const data = {};
    
    // 过滤掉 ships 字段和 display 类型的字段，确保它们不会被保存
    const formFields = config.fields.filter(field => {
        // 跳过 display 类型的字段
        if (field.type === 'display') {
            return false;
        }
        // 明确跳过 ships 字段（船公司和管理公司的船舶字段，由船舶表绑定，不需要保存）
        if (field.key === 'ships') {
            return false;
        }
        return true;
    });
    
    formFields.forEach(field => {
        
        if (field.type === 'checkbox' && !field.multiple) {
            // 单个复选框
            const input = document.getElementById(field.key);
            data[field.key] = input.checked;
        } else if (field.type === 'select' && field.multiple) {
            // 多选复选框：从复选框容器中获取所有选中的值
            const container = document.getElementById(field.key + '_container');
            if (container) {
                const checkboxes = container.querySelectorAll('input[type="checkbox"]:checked');
                if (checkboxes.length > 0) {
                    data[field.key] = Array.from(checkboxes).map(cb => cb.value).join(', ');
                } else {
                    data[field.key] = ''; // 如果没有选择任何选项，保存为空字符串
                }
            } else {
                data[field.key] = '';
            }
        } else if (field.type === 'select') {
            // 单选下拉框
            const input = document.getElementById(field.key);
            data[field.key] = input.value || '';
        } else {
            const value = formData.get(field.key);
            if (field.type === 'number') {
                data[field.key] = value ? parseInt(value) : 0;
            } else {
                data[field.key] = value || '';
            }
        }
    });
    
    try {
        const url = config.api + (editingId ? '/' + editingId : '');
        const method = editingId ? 'PUT' : 'POST';
        
        const response = await fetch(url, {
            method: method,
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
        });
        
        const result = await response.json();
        
        if (result.success) {
            closeModal();
            loadData();
            alert(editingId ? '更新成功' : '添加成功');
        } else {
            alert('操作失败: ' + result.message);
        }
    } catch (error) {
        console.error('Error:', error);
        alert('操作失败');
    }
}

// 删除数据
async function deleteItem(id) {
    if (!confirm('确定要删除这条记录吗？')) {
        return;
    }
    
    const config = tabConfig[currentTab];
    
    try {
        const response = await fetch(config.api + '/' + id, {
            method: 'DELETE'
        });
        
        const result = await response.json();
        
        if (result.success) {
            loadData();
            alert('删除成功');
        } else {
            alert('删除失败: ' + result.message);
        }
    } catch (error) {
        console.error('Error:', error);
        alert('删除失败');
    }
}

// 查看详情
async function viewDetail(id) {
    const config = tabConfig[currentTab];
    
    try {
        const response = await fetch(config.api + '/' + id);
        const result = await response.json();
        
        if (result.success) {
            const item = result.data;
            const detailContent = document.getElementById('detailContent');
            detailContent.innerHTML = '';
            
            config.fields.forEach(field => {
                const detailItem = document.createElement('div');
                detailItem.className = 'detail-item';
                
                const label = document.createElement('div');
                label.className = 'detail-label';
                label.textContent = field.label + ':';
                
                const value = document.createElement('div');
                value.className = 'detail-value';
                let val;
                if (field.key === 'ships') {
                    val = getShipsLikeValue(item);
                } else {
                    val = item[field.key];
                }
                if (val === undefined || val === null || val === '') {
                    val = '-';
                } else if (field.key === 'ships') {
                    // 船舶列表：详情中展示完整内容
                    val = formatShipListForDetail(val);
                } else if (Array.isArray(val)) {
                    // 如果是数组，显示为逗号分隔的字符串
                    val = val.length > 0 ? val.join(', ') : '-';
                } else if (typeof val === 'boolean') {
                    val = val ? '是' : '否';
                }
                value.textContent = val;
                
                detailItem.appendChild(label);
                detailItem.appendChild(value);
                detailContent.appendChild(detailItem);
            });
            
            document.getElementById('detailModal').style.display = 'block';
        } else {
            alert('加载详情失败: ' + result.message);
        }
    } catch (error) {
        console.error('Error:', error);
        alert('加载详情失败');
    }
}

// 关闭模态框
function closeModal() {
    document.getElementById('formModal').style.display = 'none';
}

function closeDetailModal() {
    document.getElementById('detailModal').style.display = 'none';
}

// 搜索处理
let currentFilters = {}; // 当前筛选条件

function handleSearchKeyup(event) {
    // 如果按Enter键，立即搜索
    if (event.key === 'Enter') {
        event.preventDefault();
        performSearch();
        return;
    }
    
    // 移除自动搜索功能，只有点击搜索按钮或按Enter键才会搜索
}

// 执行搜索
function performSearch() {
    const keyword = document.getElementById('searchInput').value.trim();
    loadData(keyword);
}

// 显示筛选模态框
function showFilterModal() {
    const config = tabConfig[currentTab];
    const modal = document.getElementById('filterModal');
    const filterContent = document.getElementById('filterContent');
    
    filterContent.innerHTML = '';
    
    // 为每个字段创建筛选输入框
    config.fields.forEach(field => {
        // 跳过某些字段类型，但允许备注字段参与筛选
        if (field.type === 'display' || (field.type === 'checkbox' && !field.multiple)) {
            return;
        }
        // 备注字段虽然是 textarea，但需要支持关键词筛选
        if (field.type === 'textarea' && field.key !== 'remark') {
            return;
        }
        
        const group = document.createElement('div');
        group.className = 'form-group';
        
        const label = document.createElement('label');
        label.textContent = field.label;
        
        let input;
        if (field.type === 'select' && field.multiple) {
            // 多选字段：使用文本输入，支持逗号分隔
            input = document.createElement('input');
            input.type = 'text';
            input.placeholder = '多个值用逗号分隔';
            input.id = 'filter_' + field.key;
            input.value = currentFilters[field.key] || '';
        } else if (field.type === 'select') {
            // 单选下拉框
            input = document.createElement('select');
            input.id = 'filter_' + field.key;
            
            const emptyOption = document.createElement('option');
            emptyOption.value = '';
            emptyOption.textContent = '全部';
            input.appendChild(emptyOption);
            
            // 加载选项
            let options = [];
            if (field.options) {
                // 静态选项（如：公司属性的选项）
                options = field.options.map(opt => ({ id: opt, name: opt }));
            } else if (field.relation === 'school') {
                options = schoolNames;
            } else if (field.relation === 'ship') {
                options = shipNames;
            } else if (field.relation === 'company') {
                options = companyNames;
            } else if (field.relation === 'management') {
                options = managementNames;
            }
            
            options.forEach(option => {
                const opt = document.createElement('option');
                opt.value = option.name;
                opt.textContent = option.name;
                if (currentFilters[field.key] === option.name) {
                    opt.selected = true;
                }
                input.appendChild(opt);
            });
        } else if (field.type === 'number') {
            // 数字字段：创建范围输入
            const rangeGroup = document.createElement('div');
            rangeGroup.style.display = 'flex';
            rangeGroup.style.gap = '10px';
            rangeGroup.style.alignItems = 'center';
            
            const minInput = document.createElement('input');
            minInput.type = 'number';
            minInput.placeholder = '最小值';
            minInput.id = 'filter_' + field.key + '_min';
            minInput.value = currentFilters[field.key + '_min'] || '';
            minInput.style.flex = '1';
            
            const maxInput = document.createElement('input');
            maxInput.type = 'number';
            maxInput.placeholder = '最大值';
            maxInput.id = 'filter_' + field.key + '_max';
            maxInput.value = currentFilters[field.key + '_max'] || '';
            maxInput.style.flex = '1';
            
            rangeGroup.appendChild(minInput);
            rangeGroup.appendChild(maxInput);
            input = rangeGroup;
        } else if (field.type === 'textarea' && field.key === 'remark') {
            // 备注字段：使用文本输入框支持关键词查询
            input = document.createElement('input');
            input.type = 'text';
            input.id = 'filter_' + field.key;
            input.value = currentFilters[field.key] || '';
            input.placeholder = '输入备注关键词筛选';
        } else {
            // 文本字段
            input = document.createElement('input');
            input.type = 'text';
            input.id = 'filter_' + field.key;
            input.value = currentFilters[field.key] || '';
            input.placeholder = '输入关键词筛选';
        }
        
        group.appendChild(label);
        group.appendChild(input);
        filterContent.appendChild(group);
    });
    
    modal.style.display = 'block';
}

// 应用筛选
function applyFilter() {
    const config = tabConfig[currentTab];
    const filters = {};
    
    config.fields.forEach(field => {
        if (field.type === 'display' || (field.type === 'checkbox' && !field.multiple)) {
            return;
        }
        // 备注字段虽然是 textarea，但需要支持关键词筛选
        if (field.type === 'textarea' && field.key !== 'remark') {
            return;
        }
        
        if (field.type === 'number') {
            const minInput = document.getElementById('filter_' + field.key + '_min');
            const maxInput = document.getElementById('filter_' + field.key + '_max');
            if (minInput && minInput.value) {
                filters[field.key + '_min'] = minInput.value;
            }
            if (maxInput && maxInput.value) {
                filters[field.key + '_max'] = maxInput.value;
            }
        } else {
            const input = document.getElementById('filter_' + field.key);
            if (input && input.value) {
                filters[field.key] = input.value.trim();
            }
        }
    });
    
    currentFilters = filters;
    closeFilterModal();
    loadData('', filters);
}

// 重置筛选
function resetFilter() {
    currentFilters = {};
    const config = tabConfig[currentTab];
    
    config.fields.forEach(field => {
        if ((field.type === 'checkbox' && !field.multiple)) {
            return;
        }
        // 备注字段虽然是 textarea，但需要支持关键词筛选
        if (field.type === 'textarea' && field.key !== 'remark') {
            return;
        }
        
        if (field.type === 'number') {
            const minInput = document.getElementById('filter_' + field.key + '_min');
            const maxInput = document.getElementById('filter_' + field.key + '_max');
            if (minInput) minInput.value = '';
            if (maxInput) maxInput.value = '';
        } else {
            const input = document.getElementById('filter_' + field.key);
            if (input) input.value = '';
        }
    });
    
    loadData();
}

// 关闭筛选模态框
function closeFilterModal() {
    document.getElementById('filterModal').style.display = 'none';
}

// 点击模态框外部关闭
window.onclick = function(event) {
    const formModal = document.getElementById('formModal');
    const detailModal = document.getElementById('detailModal');
    const filterModal = document.getElementById('filterModal');
    
    if (event.target === formModal) {
        closeModal();
    }
    if (event.target === detailModal) {
        closeDetailModal();
    }
    if (event.target === filterModal) {
        closeFilterModal();
    }
}

// 页面加载时初始化
document.addEventListener('DOMContentLoaded', function() {
    loadRelationData();
    loadData();
});
