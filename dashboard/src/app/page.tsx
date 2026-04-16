'use client';

import React, { useState, useEffect } from 'react';
import { db } from '@/lib/firebase';
import { ref, onValue, off } from 'firebase/database';
import { MediFlowAI, RedistributionPlan, InventoryItem, Facility } from '@/lib/ai/engine';
import { ExplainSidebar } from '@/components/ExplainSidebar';
import { generateMockData } from '@/lib/ai/mockData';
import { 
  Activity, 
  Box, 
  Zap, 
  Search, 
  LayoutDashboard, 
  Database, 
  Layers, 
  Map as MapIcon,
  AlertTriangle,
  ArrowRightLeft,
  ChevronRight,
  TrendingUp,
  BrainCircuit,
  Cpu
} from 'lucide-react';

export default function Home() {
  const [data, setData] = useState<{ facilities: Facility[], inventory: InventoryItem[] } | null>(null);
  const [plans, setPlans] = useState<RedistributionPlan[]>([]);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [activeTab, setActiveTab] = useState<'intelligence' | 'market'>('intelligence');
  const [simulationMode, setSimulationMode] = useState(false);
  const [selectedPlan, setSelectedPlan] = useState<RedistributionPlan | null>(null);

  useEffect(() => {
    if (!db) {
      setData(generateMockData());
      return;
    }

    const facilitiesRef = ref(db, 'facilities');
    const inventoryRef = ref(db, 'inventory');

    const unsubscribeFacilities = onValue(facilitiesRef, (snapshot) => {
      const facilitiesData = snapshot.val();
      if (facilitiesData) {
        const facilitiesList = Object.values(facilitiesData) as Facility[];
        
        onValue(inventoryRef, (invSnapshot) => {
          const inventoryData = invSnapshot.val();
          if (inventoryData) {
            const inventoryList: InventoryItem[] = [];
            Object.values(inventoryData).forEach((facInventory: any) => {
              Object.values(facInventory).forEach((item: any) => {
                inventoryList.push(item);
              });
            });
            setData({ facilities: facilitiesList, inventory: inventoryList });
          }
        });
      }
    });

    return () => {
      off(facilitiesRef);
      off(inventoryRef);
    };
  }, []);

  const runAnalysis = () => {
    if (!data) return;
    setIsAnalyzing(true);
    
    setTimeout(() => {
      const consumptionRates: Record<string, number> = {
        'Insulin': simulationMode ? 40 : 13,
        'Paracetamol': 50,
        'Amoxicillin': 20,
        'Azithromycin': 15,
        'Metformin': 30,
        'Amlodipine': 25
      };
      
      const risks = MediFlowAI.predictExpiryRisk(data.inventory, consumptionRates);
      
      const demands: Record<string, Record<string, number>> = {};
      data.facilities.forEach(f => {
        if (f.type !== 'PHC') {
          demands[f.id] = {
            'Insulin': Math.floor(Math.random() * (simulationMode ? 500 : 200)),
            'Paracetamol': Math.floor(Math.random() * 500)
          };
        }
      });
      
      const newPlans = MediFlowAI.generateRedistribution(risks, data.facilities, demands);
      setPlans(newPlans);
      setIsAnalyzing(false);
    }, 1500);
  };

  if (!data) return (
    <div style={{ background: 'var(--background)', color: 'white', height: '100vh', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
      <div className="loader" style={{ marginBottom: '2rem' }}>
        <Cpu size={48} className="pulse" style={{ color: 'var(--primary)' }} />
      </div>
      <h3 className="gradient-text-v3" style={{ fontSize: '1.5rem' }}>Synchronizing Neural Network...</h3>
      <p style={{ color: 'var(--text-muted)', marginTop: '0.5rem', fontSize: '0.9rem' }}>MediFlow 2.0 Core Initialization</p>
    </div>
  );

  const riskCount = data.inventory.filter(i => {
    const d = new Date(i.expiryDate);
    return d < new Date(Date.now() + 30 * 24 * 3600 * 1000);
  }).length;

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--background)' }}>
      {/* Sidebar Navigation */}
      <aside className="sidebar-nav glass-v3" style={{ borderRight: '1px solid var(--glass-border)', borderRadius: '0 24px 24px 0' }}>
        <div style={{ padding: '1rem 0', marginBottom: '1rem' }}>
          <h2 className="gradient-text-v3" style={{ fontSize: '1.8rem', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <Activity color="var(--primary)" size={32} />
            MediFlow
          </h2>
        </div>
        
        <nav style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
          <div className={`nav-item ${activeTab === 'intelligence' ? 'active' : ''}`} onClick={() => setActiveTab('intelligence')}>
            <LayoutDashboard size={20} />
            Intelligence Hub
          </div>
          <div className={`nav-item ${activeTab === 'market' ? 'active' : ''}`} onClick={() => setActiveTab('market')}>
            <ArrowRightLeft size={20} />
            Stock Exchange
          </div>
          <div className="nav-item">
            <Database size={20} />
            Audit Logs
          </div>
          <div className="nav-item">
            <Layers size={20} />
            Simulations
          </div>
        </nav>

        <div style={{ marginTop: 'auto', paddingTop: '2rem' }}>
           <div className="card-v3" style={{ padding: '1rem', background: 'rgba(6, 182, 212, 0.05)' }}>
              <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginBottom: '0.5rem' }}>System Status</p>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.85rem' }}>
                <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--secondary)', boxShadow: '0 0 10px var(--secondary)' }}></div>
                Neural Engine Online
              </div>
           </div>
        </div>
      </aside>

      {/* Main Content */}
      <main style={{ flex: 1, padding: '2.5rem', marginLeft: '280px', maxWidth: '1600px' }}>
        <ExplainSidebar 
          isOpen={!!selectedPlan} 
          onClose={() => setSelectedPlan(null)} 
          plan={selectedPlan} 
        />

        <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '3rem' }}>
          <div>
            <h1 className="gradient-text-v3" style={{ fontSize: '2.8rem', marginBottom: '0.5rem' }}>Intelligence Network</h1>
            <p style={{ color: 'var(--text-muted)', fontSize: '1.1rem' }}>Autonomous Supply-Chain Strategy & Real-time Optimization</p>
          </div>
          <div style={{ display: 'flex', gap: '1.25rem' }}>
            <button className="btn-v3 glass-v3" style={{ color: 'white' }}>
              <Search size={18} />
              Network Search
            </button>
            <button className="btn-v3 btn-primary-v3" onClick={runAnalysis} disabled={isAnalyzing}>
              {isAnalyzing ? <Activity className="rotate" size={18} /> : <BrainCircuit size={18} />}
              {isAnalyzing ? 'Synchronizing Optima...' : 'Run Neural Analysis'}
            </button>
          </div>
        </header>

        {activeTab === 'intelligence' ? (
          <>
            {/* Top Stats */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '1.75rem', marginBottom: '3rem' }}>
              <div className="card-v3">
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '1rem' }}>
                   <div style={{ padding: '0.5rem', borderRadius: '12px', background: 'rgba(6, 182, 212, 0.1)', color: 'var(--primary)' }}>
                      <Box size={22} />
                   </div>
                   <TrendingUp size={18} style={{ color: 'var(--secondary)' }} />
                </div>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', fontWeight: '500' }}>Active Facilities</p>
                <h3 style={{ fontSize: '2.4rem', marginTop: '0.5rem', fontWeight: '700' }}>{data.facilities.length}</h3>
              </div>

              <div className="card-v3">
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '1rem' }}>
                   <div style={{ padding: '0.5rem', borderRadius: '12px', background: 'rgba(244, 63, 94, 0.1)', color: 'var(--error)' }}>
                      <AlertTriangle size={22} />
                   </div>
                   <span style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem', borderRadius: '20px', background: 'rgba(244, 63, 94, 0.2)', color: 'var(--error)' }}>Critical</span>
                </div>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', fontWeight: '500' }}>Expiry Risks</p>
                <h3 style={{ fontSize: '2.4rem', marginTop: '0.5rem', fontWeight: '700', color: 'var(--error)' }}>{riskCount}</h3>
              </div>

              <div className="card-v3">
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '1rem' }}>
                   <div style={{ padding: '0.5rem', borderRadius: '12px', background: 'rgba(99, 102, 241, 0.1)', color: 'var(--accent)' }}>
                      <Zap size={22} />
                   </div>
                   <span style={{ fontSize: '0.75rem', color: 'var(--primary)' }}>+12% vs last mo</span>
                </div>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', fontWeight: '500' }}>Optimization Efficiency</p>
                <h3 style={{ fontSize: '2.4rem', marginTop: '0.5rem', fontWeight: '700' }}>{simulationMode ? '98.2%' : '84.5%'}</h3>
              </div>

              <div 
                className="card-v3" 
                style={{ cursor: 'pointer', borderLeft: simulationMode ? '4px solid var(--accent)' : '1px solid var(--card-border)' }} 
                onClick={() => setSimulationMode(!simulationMode)}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '1rem' }}>
                   <div style={{ padding: '0.5rem', borderRadius: '12px', background: simulationMode ? 'rgba(99, 102, 241, 0.2)' : 'rgba(255,255,255,0.05)' }}>
                      <Layers size={22} color={simulationMode ? 'var(--accent)' : 'var(--text-muted)'} />
                   </div>
                   <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: simulationMode ? 'var(--secondary)' : 'var(--error)', boxShadow: `0 0 10px ${simulationMode ? 'var(--secondary)' : 'var(--error)'}` }}></div>
                </div>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', fontWeight: '500' }}>Antigravity Scenario</p>
                <h3 style={{ fontSize: '1.2rem', marginTop: '0.5rem', fontWeight: '600', color: simulationMode ? 'var(--accent)' : 'inherit' }}>
                  {simulationMode ? 'Viral Outbreak Spike' : 'Real-time Feed'}
                </h3>
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '2rem' }}>
              <section className="card-v3" style={{ minHeight: '450px', background: 'rgba(15, 23, 42, 0.8)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
                  <h2 style={{ fontSize: '1.5rem', fontWeight: '700', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                    <MapIcon size={24} color="var(--primary)" />
                    Network Visualization
                  </h2>
                  <div style={{ display: 'flex', gap: '0.5rem' }}>
                     <span className="glass-v3" style={{ padding: '0.3rem 0.75rem', fontSize: '0.7rem', color: 'var(--secondary)', border: '1px solid var(--secondary-glow)' }}>LIVE_FEED_SYNC</span>
                  </div>
                </div>
                
                <div style={{ 
                  width: '100%', 
                  height: '420px', 
                  background: 'radial-gradient(circle at center, rgba(6, 182, 212, 0.03) 0%, transparent 70%)', 
                  borderRadius: '16px',
                  position: 'relative',
                  overflow: 'hidden',
                  border: '1px solid rgba(255,255,255,0.05)'
                }}>
                   {/* Map Grid Pattern */}
                   <div style={{ position: 'absolute', inset: 0, backgroundImage: 'radial-gradient(rgba(255,255,255,0.05) 1px, transparent 1px)', backgroundSize: '24px 24px', opacity: 0.5 }}></div>
                   
                   {data.facilities.slice(0, 40).map((f) => (
                     <div key={f.id} style={{ 
                       position: 'absolute', 
                       left: `${(f.lon - 77.0) * 1000}%`, 
                       top: `${(f.lat - 28.4) * 1000}%`,
                       width: f.type === 'DH' ? '14px' : '10px',
                       height: f.type === 'DH' ? '14px' : '10px',
                       borderRadius: '50%',
                       background: f.type === 'DH' ? 'var(--primary)' : 'var(--secondary)',
                       boxShadow: `0 0 20px ${f.type === 'DH' ? 'var(--primary-glow)' : 'var(--secondary-glow)'}`,
                       transition: 'all 0.5s ease',
                       cursor: 'pointer'
                     }} className="pulse-soft" />
                   ))}
                   {plans.slice(0, 20).map((p, i) => {
                     const src = data.facilities.find(f => f.id === p.sourceId);
                     const dst = data.facilities.find(f => f.id === p.destinationId);
                     if (!src || !dst) return null;
                     return (
                       <svg key={i} style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%', pointerEvents: 'none', zIndex: 1 }}>
                          <line 
                            x1={`${(src.lon - 77.0) * 1000}%`} 
                            y1={`${(src.lat - 28.4) * 1000}%`} 
                            x2={`${(dst.lon - 77.0) * 1000}%`} 
                            y2={`${(dst.lat - 28.4) * 1000}%`} 
                            stroke={p.urgency === 'high' ? 'var(--error)' : 'var(--primary)'}
                            strokeWidth="1.5"
                            strokeDasharray="5,5"
                            opacity="0.4"
                          />
                       </svg>
                     );
                   })}
                </div>
              </section>

              <section className="card-v3" style={{ display: 'flex', flexDirection: 'column', background: 'rgba(15, 23, 42, 0.8)' }}>
                <h2 style={{ fontSize: '1.5rem', fontWeight: '700', marginBottom: '2rem', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                  <Zap size={24} color="var(--warning)" />
                  AI Recommendations
                </h2>
                <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '1.25rem', maxHeight: '450px', paddingRight: '0.75rem' }}>
                  {plans.length === 0 ? (
                    <div style={{ textAlign: 'center', marginTop: '6rem' }}>
                      <BrainCircuit size={48} color="var(--text-muted)" style={{ opacity: 0.3, marginBottom: '1rem' }} />
                      <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>Awaiting network synchronization...</p>
                    </div>
                  ) : (
                    plans.map((p, i) => (
                      <div key={i} className="glass-v3" style={{ padding: '1.25rem', borderLeft: p.urgency === 'high' ? '4px solid var(--error)' : '4px solid var(--primary)', transition: 'transform 0.2s ease' }} onMouseEnter={(e) => e.currentTarget.style.transform = 'scale(1.02)'} onMouseLeave={(e) => e.currentTarget.style.transform = 'scale(1)'}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
                          <span style={{ fontWeight: '700', color: 'white', fontSize: '1rem' }}>{p.itemName}</span>
                          <span style={{ color: 'var(--primary)', fontWeight: '600', fontSize: '0.9rem' }}>{p.quantity} Units</span>
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: 'var(--text-muted)', fontSize: '0.75rem', marginBottom: '1rem' }}>
                          {p.sourceId} <ChevronRight size={12} /> {p.destinationId}
                        </div>
                        <div style={{ display: 'flex', gap: '0.75rem' }}>
                           <button className="btn-v3 btn-primary-v3" style={{ padding: '0.4rem 0.8rem', fontSize: '0.75rem', flex: 1 }}>Execute</button>
                           <button 
                            onClick={() => setSelectedPlan(p)}
                            className="btn-v3 glass-v3" 
                            style={{ padding: '0.4rem 0.8rem', fontSize: '0.75rem', color: 'white' }}
                           >Intelligence Report</button>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </section>
            </div>
          </>
        ) : (
          <section className="card-v3" style={{ background: 'rgba(15, 23, 42, 0.8)' }}>
            <h2 style={{ fontSize: '1.8rem', fontWeight: '700', marginBottom: '2.5rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
              <ArrowRightLeft size={28} color="var(--primary)" />
              B2B Medicine Exchange
            </h2>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '2rem' }}>
              {[1, 2, 3, 4, 5, 6].map(i => (
                <div key={i} className="card-v3" style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.05)' }}>
                   <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '1.5rem' }}>
                     <span className="glass-v3" style={{ padding: '0.3rem 0.75rem', fontSize: '0.65rem', fontWeight: '700', background: i % 2 === 0 ? 'rgba(16, 185, 129, 0.1)' : 'rgba(99, 102, 241, 0.1)', color: i % 2 === 0 ? 'var(--secondary)' : 'var(--accent)', border: `1px solid ${i % 2 === 0 ? 'var(--secondary-glow)' : 'var(--accent)'}` }}>
                       {i % 2 === 0 ? 'AVAILABLE_SURPLUS' : 'URGENT_REQUEST'}
                     </span>
                     <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>Verified Facility</span>
                   </div>
                   <h4 style={{ fontSize: '1.25rem', marginBottom: '0.5rem', fontWeight: '700' }}>Critical Pharmaceutical {i}</h4>
                   <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginBottom: '1.5rem' }}>Hub Location: District Terminal {100 + i}</p>
                   <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span style={{ fontWeight: '800', fontSize: '1.1rem', color: 'var(--primary)' }}>{100 * i} Units</span>
                      <button className="btn-v3 btn-primary-v3" style={{ padding: '0.5rem 1.25rem', fontSize: '0.85rem' }}>
                        {i % 2 === 0 ? 'Initiate Claim' : 'Fulfill Need'}
                      </button>
                   </div>
                </div>
              ))}
            </div>
          </section>
        )}
      </main>

      <style jsx global>{`
        @keyframes pulse-soft {
          0% { opacity: 0.6; transform: scale(1); }
          100% { opacity: 1; transform: scale(1.1); }
        }
        .pulse-soft {
          animation: pulse-soft 2s infinite alternate ease-in-out;
        }
        .rotate {
          animation: rotation 2s infinite linear;
        }
        @keyframes rotation {
          from { transform: rotate(0deg); }
          to { transform: rotate(359deg); }
        }
        .pulse {
          animation: pulse-ring 1.25s cubic-bezier(0.215, 0.61, 0.355, 1) infinite;
        }
        @keyframes pulse-ring {
          0% { transform: scale(.33); }
          80%, 100% { opacity: 0; }
        }
      `}</style>
    </div>
  );
}
