const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// --------------------------------------------------------------------------
// 1. NUEVA INCIDENCIA -> Notificar a TODOS los Jefes
// --------------------------------------------------------------------------
exports.nuevaIncidencia = onDocumentCreated("incidencias/{incidenciaId}", async (event) => {
    // Si el documento no existe (borrado), no hacemos nada
    if (!event.data) return;

    const datos = event.data.data();
    
    // Configuramos el mensaje push
    const mensaje = {
        notification: {
            title: "🚨 Nueva Incidencia Reportada",
            body: `Nueva incidencia de ${datos.nombreUsuario || 'un usuario'}. Toca para ver detalles.`,
        },
        topic: "jefes" // Esto enviará a todos los suscritos al tema 'jefes'
    };

    try {
        await admin.messaging().send(mensaje);
        console.log("Notificación enviada a Jefes");
    } catch (error) {
        console.error("Error enviando a jefes:", error);
    }
});

// --------------------------------------------------------------------------
// 2. ACTUALIZACIÓN -> Asignación (al Técnico) o Resolución (al Usuario)
// --------------------------------------------------------------------------
exports.actualizacionIncidencia = onDocumentUpdated("incidencias/{incidenciaId}", async (event) => {
    // Si no hay datos antiguos o nuevos, salimos
    if (!event.data.before || !event.data.after) return;

    const antes = event.data.before.data();
    const despues = event.data.after.data();

    // --- CASO A: Jefe asigna técnico (Campo 'tecnicoId' cambia de null/vacío a un valor) ---
    // Verificamos que antes no hubiera técnico (o fuera diferente) y ahora sí haya uno
    if (despues.tecnicoId && antes.tecnicoId !== despues.tecnicoId) {
        const tecnicoId = despues.tecnicoId;

        // Buscamos el token del técnico en la colección 'usuarios'
        const tecnicoDoc = await admin.firestore().collection('usuarios').doc(tecnicoId).get();
        
        if (tecnicoDoc.exists) {
            const fcmToken = tecnicoDoc.data().fcmToken;
            if (fcmToken) {
                const mensajeTecnico = {
                    notification: {
                        title: "🛠️ Nueva Tarea Asignada",
                        body: "Se te ha asignado una incidencia. Revisa tu lista de pendientes.",
                    },
                    token: fcmToken
                };
                try {
                    await admin.messaging().send(mensajeTecnico);
                    console.log(`Notificación enviada al técnico ${tecnicoId}`);
                } catch (e) {
                    console.error("Error enviando al técnico:", e);
                }
            }
        }
    }

    // --- CASO B: Técnico resuelve (Estado cambia a 'resuelto') ---
    if (antes.estado !== 'resuelto' && despues.estado === 'resuelto') {
       const usuarioId = despues.usuario_reportante_id;

        if (usuarioId) {
            const usuarioDoc = await admin.firestore().collection('usuarios').doc(usuarioId).get();
            
            if (usuarioDoc.exists) {
                const fcmToken = usuarioDoc.data().fcmToken;
                if (fcmToken) {
                    const mensajeUsuario = {
                        notification: {
                            title: "✅ Incidencia Resuelta",
                            body: "Tu reporte ha sido solucionado. ¡Gracias por tu paciencia!",
                        },
                        token: fcmToken
                    };
                    try {
                        await admin.messaging().send(mensajeUsuario);
                        console.log(`Notificación enviada al usuario ${usuarioId}`);
                    } catch (e) {
                        console.error("Error enviando al usuario:", e);
                    }
                }
            }
        }
    }
});