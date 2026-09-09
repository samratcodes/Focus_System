// ============================================================
// FOCUS SYSTEM — Shared Engine & Gamified Backbone
// ============================================================

// ---- UTILITIES ----
function genId(){return crypto.randomUUID?crypto.randomUUID():Date.now().toString(36)+Math.random().toString(36).slice(2)}
function toDateStr(d){d=d||new Date();return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')}
function today(){return toDateStr(new Date())}
function fmtDate(iso){if(!iso)return'';const d=new Date(iso+'T00:00:00');return d.toLocaleDateString('en-US',{weekday:'short',month:'short',day:'numeric'})}
function fmtDateShort(iso){if(!iso)return'';const d=new Date(iso+'T00:00:00');return d.toLocaleDateString('en-US',{month:'short',day:'numeric'})}
function timeToMinutes(t){if(!t)return null;const[p,a]=t.split(':');let m=parseInt(p)*60+parseInt(a);return m}
function getCurrentTimeStr(){
  const now=new Date();
  return `${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`;
}
function isTimeInPast(dateStr,timeStr){
  if(!dateStr||!timeStr)return false;
  if(dateStr!==today())return false;
  const now=new Date();
  const currentMinutes=now.getHours()*60+now.getMinutes();
  const taskMinutes=timeToMinutes(timeStr);
  return taskMinutes!==null&&taskMinutes<=currentMinutes;
}
function timeMinForDate(dateStr){
  return dateStr===today()?getCurrentTimeStr():'';
}
function escHtml(s){const d=document.createElement('div');d.textContent=s;return d.innerHTML}

// ---- STATE MANAGEMENT ----
const STORAGE_KEYS={
  tasks:'fs_tasks',
  pomoSettings:'fs_pomo_settings',
  pomoLog:'fs_pomo_log',
  streaks:'fs_streaks',
  pomoStatePersist:'fs_pomo_running',
  goals:'fs_goals',
  xp:'fs_xp'
};

function load(key,fallback){try{const v=localStorage.getItem(key);return v?JSON.parse(v):fallback}catch(e){return fallback}}
function save(key,val){try{localStorage.setItem(key,JSON.stringify(val))}catch(e){}}

let state={
  tasks: load(STORAGE_KEYS.tasks, []),
  goals: load(STORAGE_KEYS.goals, [
    { id: 'g_1', title: 'Personal Growth', color: '#6366F1', icon: 'target' },
    { id: 'g_2', title: 'Work & Projects', color: '#10B981', icon: 'briefcase' }
  ]),
  xp: load(STORAGE_KEYS.xp, 0),
  pomoSettings: load(STORAGE_KEYS.pomoSettings, {work:25,shortBreak:5,longBreak:15,longBreakInterval:4}),
  pomoLog: load(STORAGE_KEYS.pomoLog, []),
  streaks: load(STORAGE_KEYS.streaks, []),
  selectedDate: today(),
  calendarMonth: new Date().getMonth(),
  calendarYear: new Date().getFullYear(),
  searchQuery: '',
  editingTaskId: null,
  activeGoalId: null
};

function persistTasks(){save(STORAGE_KEYS.tasks,state.tasks)}
function persistGoals(){save(STORAGE_KEYS.goals,state.goals)}
function persistXP(){save(STORAGE_KEYS.xp,state.xp)}
function persistPomoLog(){save(STORAGE_KEYS.pomoLog,state.pomoLog)}
function persistStreaks(){save(STORAGE_KEYS.streaks,state.streaks)}

// ---- GAMIFICATION / LEVEL SYSTEM ----
function getLevelInfo(xp){
  const currentXp = xp || state.xp;
  const level = Math.floor(currentXp / 100) + 1;
  const xpInLevel = currentXp % 100;
  return { level, xpInLevel, nextLevelXp: 100 };
}

function addXP(amount, reason){
  const prevLevel = getLevelInfo(state.xp).level;
  state.xp += amount;
  persistXP();
  const newLevel = getLevelInfo(state.xp).level;
  
  if(newLevel > prevLevel){
    toast(`🎉 LEVEL UP! You reached Level ${newLevel}!`, 'success');
  } else if(reason){
    toast(`+${amount} XP: ${reason}`, 'success');
  }
}

// ---- POMODORO ENGINE ----
let pomoState={
  running: false,
  mode: 'work',
  secondsLeft: state.pomoSettings.work*60,
  totalSeconds: state.pomoSettings.work*60,
  sessionCount: 0,
  attachedTaskId: null,
  intervalId: null,
};

function persistPomoState(){
  save(STORAGE_KEYS.pomoStatePersist, {
    running: pomoState.running,
    mode: pomoState.mode,
    secondsLeft: pomoState.secondsLeft,
    totalSeconds: pomoState.totalSeconds,
    sessionCount: pomoState.sessionCount,
    attachedTaskId: pomoState.attachedTaskId,
    savedAt: Date.now(),
  });
}

function restorePomoState(){
  const saved=load(STORAGE_KEYS.pomoStatePersist, null);
  if(!saved||!saved.running)return;
  const elapsed=Math.floor((Date.now()-saved.savedAt)/1000);
  if(elapsed<=0)return;
  let remaining=saved.secondsLeft-elapsed;
  let mode=saved.mode;
  let sessionCount=saved.sessionCount;
  let attachedTaskId=saved.attachedTaskId;

  while(remaining<=0){
    if(mode==='work'){
      sessionCount++;
      const d=today();
      const existing=attachedTaskId?state.pomoLog.find(l=>l.date===d&&l.taskId===attachedTaskId):null;
      if(existing){existing.sessions=(existing.sessions||1)+1}else{
        state.pomoLog.push({date:d,sessions:1,taskId:attachedTaskId});
      }
      persistPomoLog();
      if(attachedTaskId){
        const t=state.tasks.find(t=>t.id===attachedTaskId);
        if(t){t.pomodoroCount=(t.pomodoroCount||0)+1;persistTasks()}
      }
      addXP(25, 'Completed Focus Session');
      updateStreak();
      if(sessionCount%state.pomoSettings.longBreakInterval===0){
        mode='longBreak'; remaining+=state.pomoSettings.longBreak*60;
      }else{
        mode='shortBreak'; remaining+=state.pomoSettings.shortBreak*60;
      }
    }else{
      mode='work'; remaining+=state.pomoSettings.work*60;
    }
  }

  pomoState.running=true;
  pomoState.mode=mode;
  pomoState.secondsLeft=remaining;
  pomoState.totalSeconds=mode==='work'?state.pomoSettings.work*60:
    mode==='shortBreak'?state.pomoSettings.shortBreak*60:state.pomoSettings.longBreak*60;
  pomoState.sessionCount=sessionCount;
  pomoState.attachedTaskId=attachedTaskId;
}

window.addEventListener('beforeunload', function(){ persistPomoState(); });

function resetPomo(){
  pomoState.running=false;
  pomoState.mode='work';
  pomoState.secondsLeft=state.pomoSettings.work*60;
  pomoState.totalSeconds=state.pomoSettings.work*60;
  pomoState.sessionCount=0;
  if(pomoState.intervalId){clearInterval(pomoState.intervalId);pomoState.intervalId=null}
  persistPomoState();
}

function playChime(){
  try{
    const ctx=new(window.AudioContext||window.webkitAudioContext)();
    const notes=[523.25,659.25,783.99,1046.5];
    notes.forEach((freq,i)=>{
      const osc=ctx.createOscillator();const gain=ctx.createGain();
      osc.type='sine';osc.frequency.value=freq;
      gain.gain.setValueAtTime(0.15,ctx.currentTime+i*0.15);
      gain.gain.exponentialRampToValueAtTime(0.001,ctx.currentTime+i*0.15+0.4);
      osc.connect(gain);gain.connect(ctx.destination);
      osc.start(ctx.currentTime+i*0.15);osc.stop(ctx.currentTime+i*0.15+0.4);
    });
  }catch(e){}
}

function tickPomo(){
  if(!pomoState.running)return;
  pomoState.secondsLeft--;
  if(pomoState.secondsLeft<=0){
    playChime();
    if(pomoState.mode==='work'){
      pomoState.sessionCount++;
      logPomodoroSession();
      addXP(25, 'Focus Session Complete');
      if(pomoState.sessionCount%state.pomoSettings.longBreakInterval===0){
        pomoState.mode='longBreak';
        pomoState.secondsLeft=state.pomoSettings.longBreak*60;
        pomoState.totalSeconds=state.pomoSettings.longBreak*60;
      }else{
        pomoState.mode='shortBreak';
        pomoState.secondsLeft=state.pomoSettings.shortBreak*60;
        pomoState.totalSeconds=state.pomoSettings.shortBreak*60;
      }
    }else{
      pomoState.mode='work';
      pomoState.secondsLeft=state.pomoSettings.work*60;
      pomoState.totalSeconds=state.pomoSettings.work*60;
      toast('Break over! Ready to focus.','info');
    }
    updateStreak();
  }
  if(typeof renderPomoDisplay==='function') renderPomoDisplay();
  if(typeof renderOverlayTimer==='function') renderOverlayTimer();
  renderQuickStats();
}

function startPomo(){
  if(pomoState.running)return;
  pomoState.running=true;
  pomoState.intervalId=setInterval(tickPomo,1000);
  if(typeof renderPomoDisplay==='function') renderPomoDisplay();
}

function pausePomo(){
  pomoState.running=false;
  if(pomoState.intervalId){clearInterval(pomoState.intervalId);pomoState.intervalId=null}
  if(typeof renderPomoDisplay==='function') renderPomoDisplay();
}

function logPomodoroSession(){
  const d=today();
  const existing=pomoState.attachedTaskId?state.pomoLog.find(l=>l.date===d&&l.taskId===pomoState.attachedTaskId):null;
  if(existing){existing.sessions=(existing.sessions||1)+1}else{
    state.pomoLog.push({date:d,sessions:1,taskId:pomoState.attachedTaskId});
  }
  persistPomoLog();
  if(pomoState.attachedTaskId){
    const t=state.tasks.find(t=>t.id===pomoState.attachedTaskId);
    if(t){t.pomodoroCount=(t.pomodoroCount||0)+1;persistTasks()}
  }
}

// ---- STREAKS ----
function updateStreak(){
  const d=today();
  if(!state.streaks.includes(d)){state.streaks.push(d);persistStreaks()}
}
function getStreakCount(){
  if(!state.streaks.length)return 0;
  const sorted=[...state.streaks].sort().reverse();
  let count=0;const d=new Date(today()+'T00:00:00');
  for(const s of sorted){
    const sd=new Date(s+'T00:00:00');
    const diff=Math.round((d-sd)/(86400000));
    if(diff===count){count++}else if(diff>count)break;
  }
  return count;
}
function getStreakDays(n=30){
  const result=[];const end=new Date(today()+'T00:00:00');
  for(let i=n-1;i>=0;i--){
    const d=new Date(end);d.setDate(d.getDate()-i);
    const ds=toDateStr(d);
    result.push({date:ds,active:state.streaks.includes(ds),today:ds===today()});
  }
  return result;
}

// ---- GOAL HELPERS ----
function addGoal(title, color){
  if(!title.trim())return;
  const newGoal={ id:'g_'+genId(), title:title.trim(), color:color||'#6366F1', icon:'target' };
  state.goals.push(newGoal);
  persistGoals();
  if(typeof pageRender==='function')pageRender();
  toast('New Goal created!','success');
}
function deleteGoal(goalId){
  state.goals=state.goals.filter(g=>g.id!==goalId);
  state.tasks.forEach(t=>{ if(t.goalId===goalId)t.goalId=null; });
  persistGoals();
  persistTasks();
  if(typeof pageRender==='function')pageRender();
}
function getGoalProgress(goalId){
  const tasks = state.tasks.filter(t=>t.goalId===goalId);
  if(!tasks.length) return 0;
  const done = tasks.filter(t=>t.completed).length;
  return Math.round((done/tasks.length)*100);
}

// ---- TASK HELPERS ----
function getTasksForDate(date){return state.tasks.filter(t=>t.dueDate===date)}
function getTodayTasks(){
  let tasks = state.tasks.filter(t=>t.dueDate===today());
  if(state.activeGoalId){
    tasks = tasks.filter(t=>t.goalId===state.activeGoalId);
  }
  return tasks;
}
function getFrogTask(){return state.tasks.find(t=>t.eatTheFrog&&!t.completed&&t.dueDate===today())}
function getCompletionRate(date){
  const tasks=getTasksForDate(date);
  if(!tasks.length)return 0;
  return Math.round((tasks.filter(t=>t.completed).length/tasks.length)*100);
}
// Migrate legacy tasks so the `todayTask` flag always mirrors `dueDate === today()`.
// This stops yesterday's "today" tasks from leaking onto the Today page.
function normalizeTasks(){
  const d=today();
  let changed=false;
  state.tasks.forEach(function(t){
    const shouldBeToday=(t.dueDate===d);
    if(t.todayTask!==shouldBeToday){t.todayTask=shouldBeToday;changed=true}
  });
  if(changed)persistTasks();
}

// ---- TOAST & REWARDS ----
function toast(msg,type){
  type=type||'';
  const container=document.getElementById('toast-container');
  if(!container)return;
  const el=document.createElement('div');
  el.className='toast '+type;el.textContent=msg;
  container.appendChild(el);
  setTimeout(function(){el.style.opacity='0';el.style.transition='opacity 0.3s';setTimeout(function(){el.remove()},300)},2500);
}

// ---- RENDER HELPERS ----
function renderHeader(){
  const now=new Date();
  var hours=now.getHours();
  var greet='Good evening';
  if(hours<12)greet='Good morning';
  else if(hours<17)greet='Good afternoon';
  var g=document.getElementById('greeting');
  if(g)g.textContent=greet;
  var hd=document.getElementById('header-date');
  if(hd){
    var timeStr=now.toLocaleTimeString('en-US',{hour:'2-digit',minute:'2-digit'});
    hd.textContent=now.toLocaleDateString('en-US',{weekday:'long',month:'long',day:'numeric',year:'numeric'})+' · '+timeStr;
  }
  var rate=getCompletionRate(today());
  var bf=document.getElementById('header-bar-fill');
  if(bf)bf.style.width=rate+'%';
  var bt=document.getElementById('header-bar-text');
  if(bt)bt.textContent=rate+'%';
}

function renderQuickStats(){
  var tasks=getTodayTasks();
  var done=tasks.filter(function(t){return t.completed}).length;
  var total=tasks.length;
  var rate=total?Math.round((done/total)*100):0;
  var qc=document.getElementById('qs-completed');
  if(qc)qc.textContent=done+'/'+total;
  var qb=document.getElementById('qs-bar');
  if(qb)qb.style.width=rate+'%';
  var qs=document.getElementById('qs-streak');
  if(qs)qs.textContent=getStreakCount()+' days';
  var todayLog=state.pomoLog.filter(function(l){return l.date===today()});
  var todayPomos=todayLog.reduce(function(s,l){return s+(l.sessions||1)},0);
  var qp=document.getElementById('qs-pomos');
  if(qp)qp.textContent=todayPomos;
  var tc=document.getElementById('today-count');
  if(tc)tc.textContent=total;
  var fb=document.getElementById('focus-badge');
  if(fb)fb.style.display=pomoState.running?'inline':'none';

  // Level display update
  var lvlInfo = getLevelInfo();
  var lvlEl = document.getElementById('qs-level');
  if(lvlEl) lvlEl.textContent = `Lvl ${lvlInfo.level} (${lvlInfo.xpInLevel}/100 XP)`;
}

function updateLucide(){
  if(window.lucide)lucide.createIcons();
}

// ---- TASK CARD RENDERER ----
function renderTaskCard(t){
  var goalBadge='';
  if(t.goalId){
    var g = state.goals.find(function(g){return g.id===t.goalId});
    if(g){
      goalBadge='<span class="badge" style="background:'+g.color+'22;color:'+g.color+';border:1px solid '+g.color+'44">🎯 '+escHtml(g.title)+'</span>';
    }
  }
  var eisBadge='';
  if(t.eisenhower){
    var eisKey=t.eisenhower==='do-first'?'do-first':t.eisenhower==='schedule'?'schedule':t.eisenhower==='delegate'?'delegate':'eliminate';
    var eisLabel=t.eisenhower==='do-first'?'Do First':t.eisenhower==='schedule'?'Schedule':t.eisenhower==='delegate'?'Delegate':'Eliminate';
    eisBadge='<span class="badge badge-'+eisKey+'">'+eisLabel+'</span>';
  }
  var frogBadge=t.eatTheFrog?'<span class="badge badge-frog">Priority</span>':'';
  var todayBadge=(t.dueDate===today())?'<span class="badge badge-today">Today</span>':'';
  var timeStr='';
  if(t.startTime){
    timeStr='<span class="task-time"><i data-lucide="clock"></i> '+t.startTime;
    if(t.endTime)timeStr+=' - '+t.endTime;
    timeStr+='</span>';
  }
  var subCount='';
  if(t.subtasks && t.subtasks.length){
    var doneSubs=t.subtasks.filter(function(s){return s.completed}).length;
    subCount='<span class="task-time"><i data-lucide="list-checks"></i> '+doneSubs+'/'+t.subtasks.length+'</span>';
  }
  var pomoCount=t.pomodoroCount?'<span class="task-time"><i data-lucide="timer"></i> '+t.pomodoroCount+'</span>':'';

  var subtaskHtml='';
  if(t.subtasks && t.subtasks.length>0){
    subtaskHtml='<div class="subtasks">';
    t.subtasks.forEach(function(s){
      subtaskHtml+='<div class="subtask-item"><div class="subtask-check '+(s.completed?'done':'')+'" onclick="event.stopPropagation();toggleSubtask(\''+t.id+'\',\''+s.id+'\')">'+(s.completed?'<i data-lucide="check" style="width:12px;height:12px"></i>':'')+'</div><span class="subtask-title '+(s.completed?'done':'')+'">'+escHtml(s.title)+'</span><button class="btn-icon" onclick="event.stopPropagation();deleteSubtask(\''+t.id+'\',\''+s.id+'\')" style="padding:2px"><i data-lucide="x" style="width:12px;height:12px"></i></button></div>';
    });
    subtaskHtml+='<div class="subtask-add"><input type="text" placeholder="Add subtask..." id="subtask-input-'+t.id+'" onkeydown="if(event.key===\'Enter\')addSubtask(\''+t.id+'\')"><button class="btn btn-sm btn-secondary" onclick="addSubtask(\''+t.id+'\')">+</button></div></div>';
  }

  return '<div class="task-card '+(t.completed?'completed':'')+'" draggable="true" data-task-id="'+t.id+'"><div class="task-check '+(t.completed?'done':'')+'" onclick="toggleComplete(\''+t.id+'\')">'+(t.completed?'<i data-lucide="check"></i>':'')+'</div><div class="task-body"><div class="task-title">'+escHtml(t.title)+'</div><div class="task-meta">'+goalBadge+frogBadge+todayBadge+eisBadge+timeStr+subCount+pomoCount+'</div>'+subtaskHtml+'</div><div class="task-actions"><button class="btn-icon" onclick="openTaskEditor(\''+t.id+'\')" title="Edit"><i data-lucide="pencil"></i></button><button class="btn-icon" onclick="toggleFrog(\''+t.id+'\')" title="'+(t.eatTheFrog?'Unmark Frog':'Eat the Frog')+'" style="color:'+(t.eatTheFrog?'var(--frog)':'')+'"><i data-lucide="zap"></i></button><button class="btn-icon" onclick="deleteTask(\''+t.id+'\')" title="Delete"><i data-lucide="trash-2"></i></button></div></div>';
}

// ---- TASK CRUD ----
function toggleComplete(id){
  var t=state.tasks.find(function(t){return t.id===id});
  if(t){
    t.completed=!t.completed;
    if(t.completed){
      t.eatTheFrog=false;
      const xpEarned = t.eatTheFrog ? 50 : 20;
      addXP(xpEarned, 'Task Completed');
    }
    persistTasks();
    updateStreak();
    pageRender();
  }
}
function completeTask(id){toggleComplete(id);}
function toggleFrog(id){
  state.tasks.forEach(function(t){if(t.id!==id)t.eatTheFrog=false});
  var t=state.tasks.find(function(t){return t.id===id});
  if(t){t.eatTheFrog=!t.eatTheFrog;persistTasks();pageRender()}
}
function clearFrog(){
  state.tasks.forEach(function(t){t.eatTheFrog=false});
  persistTasks();pageRender();
}
function deleteTask(id){
  if(!confirm('Delete this task?'))return;
  state.tasks=state.tasks.filter(function(t){return t.id!==id});
  persistTasks();pageRender();
}
function toggleSubtask(taskId,subId){
  var t=state.tasks.find(function(t){return t.id===taskId});
  if(!t)return;
  var s=t.subtasks.find(function(s){return s.id===subId});
  if(s){
    s.completed=!s.completed;
    if(s.completed) addXP(5, 'Subtask Completed');
    persistTasks();pageRender();
  }
}
function addSubtask(taskId){
  var input=document.getElementById('subtask-input-'+taskId);
  if(!input||!input.value.trim())return;
  var t=state.tasks.find(function(t){return t.id===taskId});
  if(!t)return;
  if(!t.subtasks) t.subtasks=[];
  t.subtasks.push({id:genId(),title:input.value.trim(),completed:false});
  input.value='';
  persistTasks();pageRender();
}
function deleteSubtask(taskId,subId){
  var t=state.tasks.find(function(t){return t.id===taskId});
  if(!t)return;
  t.subtasks=t.subtasks.filter(function(s){return s.id!==subId});
  persistTasks();pageRender();
}

// ---- TASK EDITOR MODAL ----
function openTaskEditor(taskId){
  state.editingTaskId=taskId;
  var t=taskId?state.tasks.find(function(t){return t.id===taskId}):null;
  var overlay=document.getElementById('task-modal-overlay');
  var modal=document.getElementById('task-modal');
  var eis=t&&t.eisenhower?t.eisenhower:null;
  var dueDate=t&&t.dueDate?t.dueDate:(state.selectedDate||today());
  var minTime=timeMinForDate(dueDate);
  var startVal=t&&t.startTime?t.startTime:'';
  var endVal=t&&t.endTime?t.endTime:'';
  var currentGoalId = t?t.goalId:(state.activeGoalId||'');

  var goalOptions = '<option value="">— Standalone Task —</option>' + 
    state.goals.map(function(g){ return '<option value="'+g.id+'"'+(currentGoalId===g.id?' selected':'')+'>🎯 '+escHtml(g.title)+'</option>'; }).join('');

  modal.innerHTML='<h3>'+(t?'Edit Task':'New Task')+'</h3>'+
    '<div class="form-group"><label>Title</label><input type="text" id="edit-title" value="'+(t?escHtml(t.title):'')+'"></div>'+
    '<div class="form-group"><label>Associated Goal</label><select id="edit-goal">'+goalOptions+'</select></div>'+
    '<div class="form-group"><label>Description</label><textarea id="edit-desc" rows="2">'+(t&&t.description?t.description:'')+'</textarea></div>'+
    '<div class="form-row"><div class="form-group"><label>Due Date</label><input type="date" id="edit-due" value="'+dueDate+'" min="'+today()+'" onchange="updateModalTimeMin()"></div></div>'+
    '<div class="form-row"><div class="form-group"><label>Start Time</label><input type="time" id="edit-start" value="'+startVal+'"'+(minTime?' min="'+minTime+'"':'')+'></div><div class="form-group"><label>End Time</label><input type="time" id="edit-end" value="'+endVal+'"></div></div>'+
    '<div class="form-group"><label>Eisenhower Priority</label><div class="eisenhower-selector">'+
      '<button class="eisenhower-option'+(eis==='do-first'?' selected':'')+'" onclick="selectEisenhower(\'do-first\')">Do First</button>'+
      '<button class="eisenhower-option'+(eis==='schedule'?' selected sched':'')+'" onclick="selectEisenhower(\'schedule\')">Schedule</button>'+
      '<button class="eisenhower-option'+(eis==='delegate'?' selected del':'')+'" onclick="selectEisenhower(\'delegate\')">Delegate</button>'+
      '<button class="eisenhower-option'+(eis==='eliminate'?' selected elim':'')+'" onclick="selectEisenhower(\'eliminate\')">Eliminate</button>'+
    '</div></div>'+
    '<div class="form-group" style="flex-direction:row;align-items:center;gap:8px"><input type="checkbox" id="edit-frog"'+(t&&t.eatTheFrog?' checked':'')+' style="width:18px;height:18px;accent-color:var(--frog)"><label style="text-transform:none;letter-spacing:0;font-size:14px">Mark as priority task (+50 XP)</label></div>'+
    '<div class="form-group" style="flex-direction:row;align-items:center;gap:8px"><input type="checkbox" id="edit-today"'+(t&&t.todayTask?' checked':'')+' style="width:18px;height:18px;accent-color:var(--primary)"><label style="text-transform:none;letter-spacing:0;font-size:14px">Add to Today\'s list</label></div>'+
    (t&&t.subtasks?'<div class="form-group"><label>Subtasks</label>'+
      t.subtasks.map(function(s){return '<div style="display:flex;gap:6px;align-items:center;margin-bottom:4px"><input type="text" value="'+escHtml(s.title)+'" data-subtask-id="'+s.id+'" style="flex:1;padding:6px 10px;border-radius:var(--radius-xs);border:1px solid var(--border);background:var(--bg-surface2);color:var(--text);font-size:13px"><button class="btn-icon" onclick="deleteSubtaskFromModal(\''+s.id+'\')"><i data-lucide="x"></i></button></div>'}).join('')+
      '<div style="display:flex;gap:6px"><input type="text" id="edit-new-subtask" placeholder="Add subtask..." style="flex:1;padding:6px 10px;border-radius:var(--radius-xs);border:1px solid var(--border);background:var(--bg-surface2);color:var(--text);font-size:13px"><button class="btn btn-sm btn-secondary" onclick="addSubtaskInModal()">+</button></div></div>':'')+
    '<div class="modal-actions"><button class="btn btn-secondary" onclick="closeModal()">Cancel</button><button class="btn btn-danger" onclick="deleteTaskFromModal()" style="'+(t?'':'display:none')+'">Delete</button><button class="btn btn-primary" onclick="saveTaskFromModal()">'+(t?'Save Changes':'Create Task')+'</button></div>';
  window._modalEisenhower=eis;
  overlay.classList.add('active');
  updateLucide();
}

function selectEisenhower(val){
  window._modalEisenhower=window._modalEisenhower===val?null:val;
  var btns=document.querySelectorAll('.eisenhower-option');
  btns.forEach(function(b){
    b.classList.remove('selected','sched','del','elim');
    var v=b.textContent.indexOf('Do First')>=0?'do-first':b.textContent.indexOf('Schedule')>=0?'schedule':b.textContent.indexOf('Delegate')>=0?'delegate':'eliminate';
    if(v===window._modalEisenhower){
      if(v==='schedule')b.classList.add('selected','sched');
      else if(v==='delegate')b.classList.add('selected','del');
      else if(v==='eliminate')b.classList.add('selected','elim');
      else b.classList.add('selected');
    }
  });
}

function addSubtaskInModal(){
  var input=document.getElementById('edit-new-subtask');
  if(!input||!input.value.trim())return;
  var newSub={id:genId(),title:input.value.trim(),completed:false};
  if(state.editingTaskId){
    var t=state.tasks.find(function(t){return t.id===state.editingTaskId});
    if(t){
      if(!t.subtasks)t.subtasks=[];
      t.subtasks.push(newSub);
      persistTasks();
    }
  }else{
    if(!window._modalSubtasks)window._modalSubtasks=[];
    window._modalSubtasks.push(newSub);
  }
  input.value='';
  openTaskEditor(state.editingTaskId);
}

function deleteSubtaskFromModal(subId){
  if(state.editingTaskId){
    var t=state.tasks.find(function(t){return t.id===state.editingTaskId});
    if(t&&t.subtasks){t.subtasks=t.subtasks.filter(function(s){return s.id!==subId});persistTasks()}
  }
  if(window._modalSubtasks){
    window._modalSubtasks=window._modalSubtasks.filter(function(s){return s.id!==subId});
  }
  openTaskEditor(state.editingTaskId);
}

function saveTaskFromModal(){
  var titleEl=document.getElementById('edit-title');
  var title=titleEl?titleEl.value.trim():'';
  if(!title){toast('Title is required','error');return}
  var goalEl=document.getElementById('edit-goal');
  var goalId=goalEl?goalEl.value||null:null;
  var todayEl=document.getElementById('edit-today');
  var todayCheck=todayEl?todayEl.checked:false;
  var dueEl=document.getElementById('edit-due');
  var due=dueEl?dueEl.value:null;
  if(todayCheck){due=today()}
  if(due&&due<today()){toast('Cannot schedule tasks in the past','error');return}
  var startEl=document.getElementById('edit-start');
  var start=startEl?startEl.value:null;
  if(isTimeInPast(due||state.selectedDate,start)){toast('Cannot set a start time in the past for today','error');return}
  var descEl=document.getElementById('edit-desc');
  var desc=descEl?descEl.value:'';
  var endEl=document.getElementById('edit-end');
  var end=endEl?endEl.value:null;
  var frogEl=document.getElementById('edit-frog');
  var frog=frogEl?frogEl.checked:false;
  var eis=window._modalEisenhower||null;

  if(state.editingTaskId){
    var t=state.tasks.find(function(t){return t.id===state.editingTaskId});
    if(t){
      t.title=title;t.goalId=goalId;t.description=desc;t.dueDate=due;t.startTime=start;t.endTime=end;
      t.eisenhower=eis;t.todayTask=(due===today());
      if(frog&&!t.eatTheFrog){state.tasks.forEach(function(x){x.eatTheFrog=false})}
      t.eatTheFrog=frog;
      if(window._modalSubtasks&&window._modalSubtasks.length>0){
        if(!t.subtasks)t.subtasks=[];
        t.subtasks.push.apply(t.subtasks,window._modalSubtasks);
        window._modalSubtasks=[];
      }
    }
  }else{
    if(frog)state.tasks.forEach(function(x){x.eatTheFrog=false});
    var newTask={
      id:genId(),title:title,goalId:goalId,description:desc,completed:false,createdAt:new Date().toISOString(),
      dueDate:due||state.selectedDate,startTime:start,endTime:end,
      duration:null,eisenhower:eis,eatTheFrog:frog,todayTask:(due===today()),
      subtasks:window._modalSubtasks||[],tags:[],pomodoroCount:0,
    };
    state.tasks.push(newTask);
    window._modalSubtasks=[];
  }
  persistTasks();
  closeModal();
  pageRender();
}

function deleteTaskFromModal(){
  if(!state.editingTaskId)return;
  if(!confirm('Delete this task?'))return;
  state.tasks=state.tasks.filter(function(t){return t.id!==state.editingTaskId});
  persistTasks();
  closeModal();
  pageRender();
}

function closeModal(){
  var overlay=document.getElementById('task-modal-overlay');
  if(overlay)overlay.classList.remove('active');
  state.editingTaskId=null;
  window._modalEisenhower=null;
  window._modalSubtasks=[];
  window._modalPreFillTime=null;
}

function updateModalTimeMin(){
  var dueEl=document.getElementById('edit-due');
  var due=dueEl?dueEl.value:'';
  var startInput=document.getElementById('edit-start');
  if(!startInput)return;
  var minTime=timeMinForDate(due||'');
  if(minTime){startInput.min=minTime}else{startInput.removeAttribute('min')}
}

// ---- FOCUS OVERLAY ----
function enterFocusOverlay(){
  var overlay=document.getElementById('focus-overlay');
  if(!overlay)return;
  overlay.classList.add('active');
  var t=pomoState.attachedTaskId?state.tasks.find(function(t){return t.id===pomoState.attachedTaskId}):null;
  var ot=document.getElementById('overlay-task-name');
  if(ot)ot.textContent=t?t.title:'Deep Work Session';
  renderOverlayTimer();
  var ol=document.getElementById('overlay-label');
  if(ol)ol.textContent=pomoState.mode==='work'?'FOCUS':pomoState.mode==='shortBreak'?'SHORT BREAK':'LONG BREAK';
}

function exitFocusOverlay(){
  var overlay=document.getElementById('focus-overlay');
  if(overlay)overlay.classList.remove('active');
}

function renderOverlayTimer(){
  var overlay=document.getElementById('focus-overlay');
  if(!overlay||!overlay.classList.contains('active'))return;
  var mins=Math.floor(pomoState.secondsLeft/60);
  var secs=pomoState.secondsLeft%60;
  var ot=document.getElementById('overlay-timer');
  if(ot)ot.textContent=String(mins).padStart(2,'0')+':'+String(secs).padStart(2,'0');
  var ol=document.getElementById('overlay-label');
  if(ol)ol.textContent=pomoState.mode==='work'?'FOCUS':pomoState.mode==='shortBreak'?'SHORT BREAK':'LONG BREAK';
}

// ---- COMMON INIT ----
function commonInit(){
  normalizeTasks();
  restorePomoState();

  var modalOverlay=document.getElementById('task-modal-overlay');
  if(modalOverlay){
    modalOverlay.addEventListener('click',function(e){if(e.target===this)closeModal()});
  }

  var exitBtn=document.getElementById('overlay-exit');
  if(exitBtn)exitBtn.addEventListener('click',exitFocusOverlay);
  var focusOverlay=document.getElementById('focus-overlay');
  if(focusOverlay){
    focusOverlay.addEventListener('click',function(e){if(e.target===this)exitFocusOverlay()});
  }

  document.addEventListener('keydown',function(e){
    if(e.key==='Escape'){
      var fo=document.getElementById('focus-overlay');
      if(fo&&fo.classList.contains('active')){exitFocusOverlay();return}
      var tmo=document.getElementById('task-modal-overlay');
      if(tmo&&tmo.classList.contains('active')){closeModal();return}
    }
    if(e.ctrlKey&&e.key==='k'){e.preventDefault();var si=document.getElementById('search-input');if(si)si.focus()}
    if(e.ctrlKey&&e.key==='n'){e.preventDefault();
      var qai=document.getElementById('quick-add-input');
      if(qai){qai.focus()}else{openTaskEditor(null)}
    }
  });

  var searchInput=document.getElementById('search-input');
  if(searchInput){
    searchInput.addEventListener('input',function(){
      state.searchQuery=this.value;
      pageRender();
    });
  }

  renderHeader();
  renderQuickStats();
  updateLucide();

  if(pomoState.running){
    pomoState.intervalId=setInterval(tickPomo,1000);
  }

  setInterval(function(){
    var now=new Date();
    if(now.getSeconds()===0)renderHeader();
  },1000);
}

// ---- GLOBAL EXPORTS ----
window.genId=genId; window.toDateStr=toDateStr; window.today=today; window.fmtDate=fmtDate; window.fmtDateShort=fmtDateShort;
window.timeToMinutes=timeToMinutes; window.isTimeInPast=isTimeInPast; window.timeMinForDate=timeMinForDate;
window.escHtml=escHtml; window.toast=toast; window.updateLucide=updateLucide;
window.getTasksForDate=getTasksForDate; window.getTodayTasks=getTodayTasks; window.getFrogTask=getFrogTask;
window.getCompletionRate=getCompletionRate; window.getStreakCount=getStreakCount; window.getStreakDays=getStreakDays;
window.updateStreak=updateStreak; window.persistTasks=persistTasks; window.persistPomoLog=persistPomoLog;
window.persistStreaks=persistStreaks; window.toggleComplete=toggleComplete; window.completeTask=completeTask;
window.toggleFrog=toggleFrog; window.clearFrog=clearFrog; window.deleteTask=deleteTask;
window.toggleSubtask=toggleSubtask; window.addSubtask=addSubtask; window.deleteSubtask=deleteSubtask;
window.openTaskEditor=openTaskEditor; window.selectEisenhower=selectEisenhower;
window.addSubtaskInModal=addSubtaskInModal; window.deleteSubtaskFromModal=deleteSubtaskFromModal;
window.saveTaskFromModal=saveTaskFromModal; window.deleteTaskFromModal=deleteTaskFromModal;
window.closeModal=closeModal; window.updateModalTimeMin=updateModalTimeMin;
window.startPomo=startPomo; window.pausePomo=pausePomo; window.resetPomo=resetPomo;
window.enterFocusOverlay=enterFocusOverlay; window.exitFocusOverlay=exitFocusOverlay;
window.renderOverlayTimer=renderOverlayTimer; window.renderPomoDisplay=renderPomoDisplay;
window.renderQuickStats=renderQuickStats; window.renderHeader=renderHeader;
window.renderTaskCard=renderTaskCard; window.commonInit=commonInit;
window.STORAGE_KEYS=STORAGE_KEYS; window.state=state; window.pomoState=pomoState;
window.load=load; window.save=save;
window.persistPomoState=persistPomoState; window.restorePomoState=restorePomoState;
window.tickPomo=tickPomo;
window.addGoal=addGoal; window.deleteGoal=deleteGoal; window.getGoalProgress=getGoalProgress;
window.addXP=addXP; window.getLevelInfo=getLevelInfo;