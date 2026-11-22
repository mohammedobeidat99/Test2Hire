import { db } from "./firebase";
import { compareTimestampsDesc } from "./formatters";
import {
  collection,
  getDocs,
  query,
  where,
  orderBy,
  limit,
  Timestamp,
} from "firebase/firestore";

export interface AuditLogRecord {
  id: string;
  actorId: string;
  actorRole: string;
  action: string;
  targetType: string;
  targetId?: string;
  metadata?: Record<string, any>;
  timestamp?: Timestamp | null;
}

export async function fetchAuditLogs(filter?: {
  targetType?: string;
  actorRole?: string;
  maxRecords?: number;
}): Promise<AuditLogRecord[]> {
  try {
    const logsRef = collection(db, "auditLogs");
    const maxRec = filter?.maxRecords || 100;
    const hasTargetFilter = Boolean(filter?.targetType && filter.targetType !== "ALL");

    let snapshot;
    if (hasTargetFilter) {
      try {
        snapshot = await getDocs(
          query(
            logsRef,
            where("targetType", "==", filter!.targetType),
            orderBy("timestamp", "desc"),
            limit(maxRec)
          )
        );
      } catch (indexErr: any) {
        if (!String(indexErr?.code || "").includes("failed-precondition")) {
          throw indexErr;
        }
        snapshot = await getDocs(
          query(logsRef, where("targetType", "==", filter!.targetType), limit(maxRec))
        );
      }
    } else {
      snapshot = await getDocs(query(logsRef, orderBy("timestamp", "desc"), limit(maxRec)));
    }
    let records = snapshot.docs.map((docSnap) => {
      const data = docSnap.data();
      return {
        id: docSnap.id,
        actorId: data.actorId || "System",
        actorRole: data.actorRole || "SYSTEM",
        action: data.action || "UNKNOWN_ACTION",
        targetType: data.targetType || "SYSTEM",
        targetId: data.targetId,
        metadata: data.metadata || {},
        timestamp: data.timestamp,
      };
    });

    if (filter?.actorRole && filter.actorRole !== "ALL") {
      records = records.filter((r) => r.actorRole === filter.actorRole);
    }

    if (hasTargetFilter) {
      records.sort((a, b) => compareTimestampsDesc(a.timestamp, b.timestamp));
    }

    return records.slice(0, maxRec);
  } catch (error) {
    console.error("Failed to fetch audit logs:", error);
    throw error;
  }
}
