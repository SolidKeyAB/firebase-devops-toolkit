const functions = require('firebase-functions');
const { getFirestore } = require('./libs/shared/firebaseAdmin');

// Firestore trigger for orchestrator service
exports.triggerOrchestrator = functions.firestore
    .document('triggers/{triggerId}')
    .onCreate(async (snap, context) => {
        const triggerData = snap.data();
        const triggerId = context.params.triggerId;
        
        console.log(`🎯 Firestore trigger activated: ${triggerId}`);
        console.log('Trigger data:', triggerData);
        
        try {
            if (triggerData.trigger_type === 'brand_processing') {
                console.log('🚀 Starting ESG pipeline for brands:', triggerData.brands);
                
                await snap.ref.update({
                    status: 'processing',
                    started_at: new Date().toISOString()
                });
                
                for (const brandId of triggerData.brands) {
                    console.log(`📊 Processing brand: ${brandId}`);
                    
                    const brandDoc = await getFirestore().collection('brands').doc(brandId).get();
                    
                    if (brandDoc.exists) {
                        const brandData = brandDoc.data();
                        console.log(`✅ Found brand data for ${brandId}:`, brandData);
                        
                        await getFirestore().collection('brands').doc(brandId).update({
                            processing_status: 'triggered',
                            triggered_at: new Date().toISOString()
                        });
                    } else {
                        console.log(`❌ Brand ${brandId} not found in Firestore`);
                    }
                }
                
                await snap.ref.update({
                    status: 'completed',
                    completed_at: new Date().toISOString()
                });
                
                console.log('✅ Pipeline trigger completed successfully');
            }
        } catch (error) {
            console.error('❌ Error in trigger function:', error);
            await snap.ref.update({
                status: 'failed',
                error: error.message,
                failed_at: new Date().toISOString()
            });
        }
    });

// Firestore trigger for brand creation
exports.triggerBrandProcessing = functions.firestore
    .document('brands/{brandId}')
    .onCreate(async (snap, context) => {
        const brandData = snap.data();
        const brandId = context.params.brandId;
        
        console.log(`📝 New brand created: ${brandId}`);
        
        try {
            await snap.ref.update({
                processing_status: 'pending',
                created_at: new Date().toISOString()
            });
            
            console.log(`✅ Brand ${brandId} ready for processing`);
        } catch (error) {
            console.error('❌ Error processing brand:', error);
        }
    });
