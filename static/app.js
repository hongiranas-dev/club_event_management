const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
async function api(url, options={}) {
  const response = await fetch(url, {headers:{'Content-Type':'application/json'}, ...options});
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || 'Request failed.');
  return data;
}
function dateText(value) { return new Date(value).toLocaleString([], {dateStyle:'medium',timeStyle:'short'}); }
async function load() {
  $('#loadError').textContent = '';
  try {
    const [summary,members,events] = await Promise.all([api('/api/summary'),api('/api/members'),api('/api/events')]);
    $('#activeCount').textContent=summary.active_members;
    $('#eventCount').textContent=summary.upcoming_events;
    $('#bookingCount').textContent=summary.total_bookings;
    $('#membersBody').innerHTML=members.length ? members.map(m=>`<tr><td>${esc(m.first_name)} ${esc(m.last_name)}</td><td>${esc(m.email)}</td><td>${esc(String(m.joined_on).slice(0,10))}</td><td><span class="status ${m.status==='inactive'?'inactive':''}">${esc(m.status)}</span></td></tr>`).join('') : '<tr><td colspan="4">No members yet.</td></tr>';
    $('#memberSelect').innerHTML='<option value="">Choose a member</option>'+members.filter(m=>m.status==='active').map(m=>`<option value="${m.member_id}">${esc(m.first_name)} ${esc(m.last_name)}</option>`).join('');
    $('#eventsList').innerHTML=events.length ? events.map(e=>`<div class="event-card"><div><h3>${esc(e.title)}</h3><p>${dateText(e.event_date)} · ${esc(e.location)}</p></div><span class="seats">${e.seats_left} seats left</span></div>`).join('') : '<p>No events scheduled.</p>';
    $('#eventSelect').innerHTML='<option value="">Choose an event</option>'+events.filter(e=>e.seats_left>0).map(e=>`<option value="${e.event_id}">${esc(e.title)} · ${dateText(e.event_date)}</option>`).join('');
  } catch (err) { $('#loadError').textContent=`Could not load club data: ${err.message} Make sure MySQL is running and the schema is imported.`; }
}
$('#memberForm').addEventListener('submit', async e=>{
  e.preventDefault(); const form=e.currentTarget; const msg=$('#memberMessage'); msg.textContent='';
  const data=Object.fromEntries(new FormData(form));
  try { await api('/api/members',{method:'POST',body:JSON.stringify(data)}); form.reset(); msg.textContent='Member added successfully.'; await load(); }
  catch(err){msg.textContent=err.message;}
});
$('#bookingForm').addEventListener('submit',async e=>{
  e.preventDefault(); const msg=$('#bookingMessage'); msg.textContent='';
  const memberId=$('#memberSelect').value, eventId=$('#eventSelect').value;
  if(!memberId || !eventId){msg.textContent='Choose both a member and an event.';return;}
  try {
    const result=await api('/api/bookings',{method:'POST',body:JSON.stringify({member_id:memberId,event_id:eventId})});
    msg.textContent=result.message || 'Booking confirmed successfully.';
    await load();
  }
  catch(err){msg.textContent=`Booking failed: ${err.message}`;}
});
load();
