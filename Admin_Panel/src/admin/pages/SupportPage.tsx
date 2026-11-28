import { useState } from 'react';
import { LifeBuoy, Send, Plus, Paperclip } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { Modal, FormInput, FormSelect } from '../components/ui/Overlays';
import { formatRelative, formatDateTime } from '../utils';

interface Ticket {
  id: string; subject: string;
  status: 'open' | 'in_progress' | 'resolved' | 'closed';
  priority: 'low' | 'medium' | 'high'; createdAt: string; updatedAt: string;
  messages: { id: string; sender: 'user' | 'support'; text: string; createdAt: string }[];
}

// TODO: replace with real support ticket API when backend endpoint is added
const MOCK_TICKETS: Ticket[] = [
  { id: 't1', subject: 'Payment verification failing for CBE', status: 'open', priority: 'high',
    createdAt: '2026-07-23T09:00:00Z', updatedAt: '2026-07-23T10:00:00Z',
    messages: [
      { id: 'm1', sender: 'user', text: 'CBE payments are failing since this morning. Reference FT2607230003 was rejected incorrectly.', createdAt: '2026-07-23T09:00:00Z' },
      { id: 'm2', sender: 'support', text: 'Thank you for reporting. We are investigating CBE verification. Can you share the error message?', createdAt: '2026-07-23T09:30:00Z' },
    ] },
  { id: 't2', subject: 'How to add a new branch?', status: 'resolved', priority: 'low',
    createdAt: '2026-07-22T14:00:00Z', updatedAt: '2026-07-22T15:00:00Z',
    messages: [
      { id: 'm3', sender: 'user', text: 'Where can I add a new branch?', createdAt: '2026-07-22T14:00:00Z' },
      { id: 'm4', sender: 'support', text: 'Go to Branches → Add Branch in the admin panel.', createdAt: '2026-07-22T14:30:00Z' },
    ] },
];

const STATUS_COLORS: Record<string, { bg: string; text: string }> = {
  open:        { bg: 'rgba(14,165,233,0.12)',  text: '#0ea5e9' },
  in_progress: { bg: 'rgba(245,158,11,0.12)',  text: '#f59e0b' },
  resolved:    { bg: 'rgba(184,255,59,0.12)',  text: '#B8FF3B' },
  closed:      { bg: 'rgba(100,116,139,0.2)',  text: '#94a3b8' },
};

const PRIORITY_COLORS: Record<string, string> = { low: '#94a3b8', medium: '#f59e0b', high: '#ef4444' };

export default function SupportPage() {
  const [selected, setSelected] = useState<Ticket | null>(MOCK_TICKETS[0]);
  const [newOpen, setNewOpen] = useState(false);
  const [reply, setReply] = useState('');

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader
        title="Support Center"
        subtitle={`${MOCK_TICKETS.filter(t => t.status === 'open' || t.status === 'in_progress').length} open tickets`}
        actions={<Btn onClick={() => setNewOpen(true)}><Plus size={14} />New Ticket</Btn>}
      />

      <div className="text-xs text-slate-600 bg-slate-900 rounded-xl p-3">
        {/* TODO: connect to real support ticket backend API */}
        Support tickets shown here are demo data. A real ticketing backend endpoint is required for full functionality.
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 h-[calc(100vh-280px)] min-h-[500px]">
        <div className="bg-card rounded-2xl border border-slate-800 flex flex-col overflow-hidden">
          <div className="px-4 py-3 border-b border-slate-800 flex-shrink-0">
            <p className="text-white font-semibold text-sm">Tickets ({MOCK_TICKETS.length})</p>
          </div>
          <div className="flex-1 overflow-y-auto scrollbar-thin divide-y divide-slate-800">
            {MOCK_TICKETS.map(ticket => {
              const sc = STATUS_COLORS[ticket.status];
              return (
                <div key={ticket.id} onClick={() => setSelected(ticket)}
                  className={`p-4 cursor-pointer hover:bg-slate-800/50 transition-colors ${selected?.id === ticket.id ? 'bg-slate-800/50 border-l-2 border-[#B8FF3B]' : ''}`}>
                  <div className="flex items-start justify-between gap-2 mb-1">
                    <p className="text-white text-sm font-medium leading-tight line-clamp-2">{ticket.subject}</p>
                    <span className="w-2 h-2 rounded-full flex-shrink-0 mt-1" style={{ background: PRIORITY_COLORS[ticket.priority] }} />
                  </div>
                  <div className="flex items-center gap-2 mt-2">
                    <span className="px-2 py-0.5 rounded-lg text-xs font-semibold" style={{ background: sc.bg, color: sc.text }}>
                      {ticket.status.replace('_', ' ')}
                    </span>
                    <span className="text-slate-600 text-xs">{formatRelative(ticket.updatedAt)}</span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <div className="lg:col-span-2 bg-card rounded-2xl border border-slate-800 flex flex-col overflow-hidden">
          {selected ? (
            <>
              <div className="px-5 py-4 border-b border-slate-800 flex-shrink-0">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="text-white font-semibold text-sm">{selected.subject}</p>
                    <p className="text-slate-500 text-xs mt-0.5">Opened {formatDateTime(selected.createdAt)}</p>
                  </div>
                  <div className="flex gap-2">
                    <span className="px-2.5 py-1 rounded-lg text-xs font-semibold" style={{ background: STATUS_COLORS[selected.status].bg, color: STATUS_COLORS[selected.status].text }}>
                      {selected.status.replace('_', ' ')}
                    </span>
                  </div>
                </div>
              </div>
              <div className="flex-1 overflow-y-auto scrollbar-thin p-5 space-y-4">
                {selected.messages.map(msg => (
                  <div key={msg.id} className={`flex ${msg.sender === 'user' ? 'justify-end' : 'justify-start'}`}>
                    <div className="max-w-[80%] rounded-2xl px-4 py-3"
                      style={msg.sender === 'user' ? { background: 'rgba(184,255,59,0.12)', borderBottomRightRadius: 4 } : { background: '#1e293b', borderBottomLeftRadius: 4 }}>
                      <p className="text-sm leading-relaxed" style={{ color: msg.sender === 'user' ? '#B8FF3B' : '#e2e8f0' }}>{msg.text}</p>
                      <p className="text-xs mt-1.5" style={{ color: msg.sender === 'user' ? 'rgba(184,255,59,0.6)' : '#475569' }}>{formatRelative(msg.createdAt)}</p>
                    </div>
                  </div>
                ))}
              </div>
              {selected.status !== 'resolved' && selected.status !== 'closed' && (
                <div className="px-5 py-4 border-t border-slate-800 flex-shrink-0">
                  <div className="flex gap-3">
                    <input value={reply} onChange={e => setReply(e.target.value)} placeholder="Type your reply…"
                      className="flex-1 bg-slate-900 border border-slate-700 rounded-xl px-4 py-2.5 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-slate-500 transition-colors"
                      onKeyDown={e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); setReply(''); } }} />
                    <button className="p-2.5 rounded-xl" style={{ background: '#B8FF3B', color: '#0f172a' }} onClick={() => setReply('')}>
                      <Send size={16} />
                    </button>
                  </div>
                </div>
              )}
            </>
          ) : (
            <div className="flex-1 flex flex-col items-center justify-center gap-3">
              <LifeBuoy size={32} className="text-slate-700" />
              <p className="text-slate-500 text-sm">Select a ticket</p>
            </div>
          )}
        </div>
      </div>

      <Modal open={newOpen} onClose={() => setNewOpen(false)} title="Create Support Ticket"
        footer={<div className="flex gap-3 justify-end"><Btn variant="secondary" onClick={() => setNewOpen(false)}>Cancel</Btn><Btn onClick={() => setNewOpen(false)}>Submit</Btn></div>}>
        <div className="space-y-4">
          <FormInput label="Subject" placeholder="Brief description of your issue" />
          <FormSelect label="Priority" defaultValue="medium">
            <option value="low">Low</option>
            <option value="medium">Medium</option>
            <option value="high">High</option>
          </FormSelect>
          <div className="flex flex-col gap-1.5">
            <label className="text-slate-300 text-sm font-medium">Description</label>
            <textarea rows={4} placeholder="Describe your issue…"
              className="bg-slate-900 border border-slate-700 rounded-xl px-4 py-2.5 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-slate-500 transition-colors resize-none" />
          </div>
        </div>
      </Modal>
    </div>
  );
}
