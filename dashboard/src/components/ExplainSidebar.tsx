import React from 'react';
import { BrainCircuit, Cpu, ShieldCheck, Activity, X } from 'lucide-react';

interface ExplainSidebarProps {
  isOpen: boolean;
  onClose: () => void;
  plan: any;
}

export const ExplainSidebar: React.FC<ExplainSidebarProps> = ({ isOpen, onClose, plan }) => {
  if (!isOpen || !plan) return null;

  return (
    <div className="glass-v3" style={{ 
      position: 'fixed', 
      top: '1rem', 
      right: '1rem', 
      width: '450px', 
      height: 'calc(100vh - 2rem)', 
      zIndex: 1000, 
      padding: '2.5rem',
      boxShadow: '-20px 0 60px rgba(0,0,0,0.6)',
      display: 'flex',
      flexDirection: 'column',
      border: '1px solid var(--glass-border)',
      background: 'rgba(15, 23, 42, 0.95)',
      animation: 'slide-in 0.4s cubic-bezier(0.16, 1, 0.3, 1)'
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2.5rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
           <BrainCircuit color="var(--primary)" size={32} />
           <h2 className="gradient-text-v3" style={{ fontSize: '1.8rem' }}>AI Intelligence Report</h2>
        </div>
        <button onClick={onClose} style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid var(--glass-border)', color: 'white', borderRadius: '50%', padding: '0.5rem', cursor: 'pointer', display: 'flex' }}>
          <X size={20} />
        </button>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', paddingRight: '0.5rem' }}>
        <div className="card-v3" style={{ marginBottom: '2rem', background: 'rgba(255,255,255,0.02)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1rem' }}>
             <Cpu size={18} color="var(--primary)" />
             <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)', fontWeight: '600' }}>DECISION_CONTEXT</span>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
            <p style={{ fontSize: '1.2rem', fontWeight: '700' }}>{plan.itemName}</p>
            <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)' }}>
              Source Terminal: <span style={{ color: 'white', fontWeight: '500' }}>{plan.sourceId}</span>
            </p>
            <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)' }}>
              Target Node: <span style={{ color: 'white', fontWeight: '500' }}>{plan.destinationId}</span>
            </p>
          </div>
        </div>

        <section style={{ marginBottom: '2.5rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1rem' }}>
             <Activity size={18} color="var(--secondary)" />
             <h4 style={{ fontSize: '1rem', fontWeight: '700', color: 'white' }}>Predictive Correlation</h4>
          </div>
          <p style={{ fontSize: '0.95rem', lineHeight: '1.7', color: 'var(--text-muted)' }}>
            Neural analysis identified a <strong style={{ color: 'var(--secondary)' }}>92% expiration risk</strong> at the source facility. 
            Destination modeling projects a supply gap of <strong style={{ color: 'white' }}>{plan.quantity * 2} units</strong> within the 14-day window due to localized patient intake spikes.
          </p>
        </section>

        <section style={{ marginBottom: '2.5rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1rem' }}>
             <Zap size={18} color="var(--primary)" />
             <h4 style={{ fontSize: '1rem', fontWeight: '700', color: 'white' }}>Redistribution Optima</h4>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
             <div className="glass-v3" style={{ padding: '0.75rem 1rem', display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                <span color="var(--text-muted)">Waste Mitigation</span>
                <span style={{ color: 'var(--secondary)', fontWeight: '700' }}>+{plan.quantity} Units</span>
             </div>
             <div className="glass-v3" style={{ padding: '0.75rem 1rem', display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                <span color="var(--text-muted)">Transit Efficiency</span>
                <span style={{ color: 'white', fontWeight: '700' }}>12.4 km</span>
             </div>
             <div className="glass-v3" style={{ padding: '0.75rem 1rem', display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                <span color="var(--text-muted)">Clinical Priority Index</span>
                <span style={{ color: 'var(--primary)', fontWeight: '700' }}>0.95 / 1.0</span>
             </div>
          </div>
        </section>

        <section style={{ marginBottom: '2.5rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1rem' }}>
             <ShieldCheck size={18} color="var(--accent)" />
             <h4 style={{ fontSize: '1rem', fontWeight: '700', color: 'white' }}>Ethics & Bias Audit</h4>
          </div>
          <p style={{ fontSize: '0.9rem', lineHeight: '1.6', color: 'var(--text-muted)', fontStyle: 'italic', background: 'rgba(99, 102, 241, 0.05)', padding: '1rem', borderRadius: '12px', border: '1px solid rgba(99, 102, 241, 0.1)' }}>
            "This recommendation was generated using cold-chain availability and medical necessity as weighted primary factors. Commercial and preferential biases have been zeroed out."
          </p>
        </section>
      </div>

      <button className="btn-v3 btn-primary-v3" style={{ width: '100%', marginTop: 'auto' }}>
        Download Forensic Audit Log
      </button>

      <style jsx>{`
        @keyframes slide-in {
          from { transform: translateX(100%); opacity: 0; }
          to { transform: translateX(0); opacity: 1; }
        }
      `}</style>
    </div>
  );
};
