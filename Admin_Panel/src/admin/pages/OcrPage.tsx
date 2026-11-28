import { useState } from 'react';
import { ScanLine, Upload, CheckCircle, XCircle } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { StatusBadge, ProviderBadge } from '../components/ui/Badges';
import { formatCurrency } from '../utils';
import api from '../services/api';

interface OcrResult {
  transactionId: string;
  amount: number;
  senderName: string;
  receiverName: string;
  provider: 'CBE' | 'TELEBIRR' | 'DASHEN' | 'ABYSSINIA' | 'CBEBIRR' | 'M_PESA';
  confidence?: number;
  status: 'VERIFIED' | 'REJECTED' | 'FAILED' | 'PENDING';
  reason?: string;
  rawData?: Record<string, unknown>;
}

export default function OcrPage() {
  const [result, setResult] = useState<OcrResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [file, setFile] = useState<File | null>(null);

  async function handleUpload(f: File) {
    setFile(f);
    setLoading(true);
    setError('');
    setResult(null);
    try {
      const form = new FormData();
      form.append('image', f);
      const res = await api.post('/payments/verify-image', form, { headers: { 'Content-Type': 'multipart/form-data' } });
      setResult(res.data);
    } catch (err: any) {
      const msg = err?.response?.data?.message ?? 'OCR verification failed';
      setError(Array.isArray(msg) ? msg.join(', ') : msg);
    } finally {
      setLoading(false);
    }
  }

  function handleDrop(e: React.DragEvent) {
    e.preventDefault();
    const f = e.dataTransfer.files[0];
    if (f && f.type.startsWith('image/')) handleUpload(f);
  }

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader title="OCR Verification" subtitle="Upload a payment screenshot for automated verification" />

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-card rounded-2xl border border-slate-800 p-6">
          <h3 className="text-white font-semibold text-sm mb-4">Upload Screenshot</h3>
          <div
            className="border-2 border-dashed border-slate-700 rounded-2xl p-10 flex flex-col items-center gap-3 cursor-pointer hover:border-[#B8FF3B]/50 transition-colors"
            onDrop={handleDrop}
            onDragOver={e => e.preventDefault()}
            onClick={() => document.getElementById('ocr-input')?.click()}
          >
            <input id="ocr-input" type="file" accept="image/*" className="hidden"
              onChange={e => { const f = e.target.files?.[0]; if (f) handleUpload(f); }} />
            <div className="w-14 h-14 rounded-2xl flex items-center justify-center" style={{ background: 'rgba(184,255,59,0.12)' }}>
              <Upload size={24} className="text-[#B8FF3B]" />
            </div>
            <p className="text-white font-medium text-sm">{file ? file.name : 'Click or drag & drop'}</p>
            <p className="text-slate-500 text-xs">PNG, JPG up to 10MB</p>
          </div>
          {error && <p className="text-red-400 text-sm mt-3 p-3 rounded-xl bg-red-500/10">{error}</p>}
          <Btn className="w-full mt-4" onClick={() => document.getElementById('ocr-input')?.click()} disabled={loading}>
            <ScanLine size={14} />{loading ? 'Processing… (may take 30-90s)' : 'Upload & Verify'}
          </Btn>
        </div>

        <div className="bg-card rounded-2xl border border-slate-800 p-6">
          <h3 className="text-white font-semibold text-sm mb-4">OCR Result</h3>
          {loading && (
            <div className="flex flex-col items-center justify-center py-12 gap-3">
              <div className="w-10 h-10 border-2 border-slate-700 border-t-[#B8FF3B] rounded-full animate-spin" />
              <p className="text-slate-400 text-sm">Extracting text from image…</p>
            </div>
          )}
          {!loading && !result && (
            <div className="flex flex-col items-center justify-center py-12 text-center">
              <ScanLine size={32} className="text-slate-700 mb-3" />
              <p className="text-slate-500 text-sm">Upload a screenshot to begin.</p>
            </div>
          )}
          {!loading && result && (
            <div className="space-y-4">
              <div className="flex items-center gap-3">
                {result.status === 'VERIFIED' ? <CheckCircle size={20} className="text-[#B8FF3B]" /> : <XCircle size={20} className="text-red-400" />}
                <StatusBadge status={result.status} />
                {result.confidence != null && <span className="text-slate-400 text-xs ml-auto">Confidence: <span className="text-[#B8FF3B] font-semibold">{result.confidence}%</span></span>}
              </div>
              <div className="bg-slate-900 rounded-xl p-4 text-center">
                <p className="text-[#B8FF3B] text-2xl font-black">{formatCurrency(result.amount)}</p>
              </div>
              {result.reason && (
                <p className="text-slate-400 text-sm p-3 rounded-xl bg-slate-900">{result.reason}</p>
              )}
              <div className="space-y-2">
                {[
                  { label: 'Transaction ID', value: result.transactionId },
                  { label: 'Sender', value: result.senderName },
                  { label: 'Receiver', value: result.receiverName },
                ].map(i => (
                  <div key={i.label} className="flex justify-between py-2 border-b border-slate-800">
                    <span className="text-slate-500 text-sm">{i.label}</span>
                    <span className="text-white text-sm font-medium">{i.value}</span>
                  </div>
                ))}
                <div className="flex justify-between py-2 border-b border-slate-800">
                  <span className="text-slate-500 text-sm">Provider</span>
                  <ProviderBadge provider={result.provider} />
                </div>
              </div>
              {result.rawData && (
                <div>
                  <p className="text-slate-400 text-xs mb-2">Raw Data</p>
                  <pre className="bg-slate-900 rounded-xl p-3 text-xs text-slate-400 whitespace-pre-wrap overflow-x-auto">
                    {JSON.stringify(result.rawData, null, 2)}
                  </pre>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
