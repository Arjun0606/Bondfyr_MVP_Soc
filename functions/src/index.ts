import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();
const storage = admin.storage();

// Scheduled function to run every hour
exports.cleanupExpiredPhotos = functions.pubsub.schedule('every 1 hours').onRun(async (context: functions.EventContext) => {
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    
    try {
        // Get expired photos
        const snapshot = await db.collection('ugc_photos')
            .where('timestamp', '<', twentyFourHoursAgo)
            .get();
        
        // No expired photos
        if (snapshot.empty) {
            console.log('No expired photos to delete');
            return null;
        }
        
        // Delete each expired photo
        const batch = db.batch();
        const deletePromises: Promise<void>[] = [];
        
        snapshot.docs.forEach(doc => {
            const data = doc.data();
            const photoURL = data.photoURL as string;
            const userId = data.userId as string;
            
            // Delete from Firestore
            batch.delete(doc.ref);
            
            // Delete from Storage
            if (photoURL) {
                const fileName = photoURL.split('/').pop();
                if (fileName) {
                    const filePath = `ugc_photos/${userId}/${fileName}`;
                    const fileRef = storage.bucket().file(filePath);
                    deletePromises.push(
                        fileRef.delete().then(() => {}).catch(err => {
                            console.error(`Error deleting file ${filePath}:`, err);
                        })
                    );
                }
            }
        });
        
        // Execute all deletions
        await Promise.all([
            batch.commit().then(() => {}),
            ...deletePromises
        ]);
        
        console.log(`Successfully deleted ${snapshot.size} expired photos`);
        return null;
    } catch (error) {
        console.error('Error cleaning up expired photos:', error);
        return null;
    }
}); 