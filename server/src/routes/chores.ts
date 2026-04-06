import { Router, Response } from "express";
import { PrismaClient } from "@prisma/client";
import { authenticate, AuthRequest } from "../middleware/auth";

const router = Router();
const prisma = new PrismaClient();

async function verifyFamilyMembership(
  userId: string,
  familyId: string,
): Promise<boolean> {
  const member = await prisma.familyMember.findUnique({
    where: { familyId_userId: { familyId, userId } },
  });
  return !!member;
}

async function recordHistory(
  choreId: string,
  familyId: string,
  userId: string,
  action: string,
) {
  await prisma.choreHistory.create({
    data: { choreId, familyId, userId, action },
  });
}

router.post(
  "/",
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const {
        id,
        familyId,
        title,
        category,
        timeSlot,
        assignedTo,
        status,
        dueDate,
        priority,
        description,
        recurrence,
      } = req.body;

      if (!familyId || !title || !category) {
        res
          .status(400)
          .json({ error: "familyId, title, and category are required" });
        return;
      }

      if (!(await verifyFamilyMembership(req.userId!, familyId))) {
        res.status(403).json({ error: "Not a member of this family" });
        return;
      }

      const chore = await prisma.chore.create({
        data: {
          id: id || undefined,
          familyId,
          title,
          category,
          timeSlot: timeSlot || null,
          assignedTo: assignedTo || null,
          assignmentStatus: assignedTo ? "pending_acceptance" : "unassigned",
          priority: priority || "medium",
          description: description || null,
          recurrence: recurrence || null,
          status: status || "pending",
          dueDate: dueDate ? new Date(dueDate) : null,
          createdBy: req.userId!,
        },
      });

      await recordHistory(chore.id, familyId, req.userId!, "created");
      if (assignedTo) {
        await recordHistory(chore.id, familyId, req.userId!, "assigned");
      }

      res.status(201).json(chore);
    } catch (error) {
      console.error("Create chore error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);

router.get(
  "/",
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const familyId = String(req.query.familyId || "");
      if (!familyId) {
        res.status(400).json({ error: "familyId query parameter is required" });
        return;
      }

      if (!(await verifyFamilyMembership(req.userId!, familyId))) {
        res.status(403).json({ error: "Not a member of this family" });
        return;
      }

      const chores = await prisma.chore.findMany({
        where: { familyId },
        orderBy: { createdAt: "desc" },
      });

      res.json(chores);
    } catch (error) {
      console.error("Get chores error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);

router.patch(
  "/:id",
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const id = String(req.params.id);
      const chore = await prisma.chore.findUnique({ where: { id } });

      if (!chore) {
        res.status(404).json({ error: "Chore not found" });
        return;
      }

      if (!(await verifyFamilyMembership(req.userId!, chore.familyId))) {
        res.status(403).json({ error: "Not a member of this family" });
        return;
      }

      const {
        title,
        category,
        timeSlot,
        assignedTo,
        status,
        dueDate,
        priority,
        description,
        recurrence,
      } = req.body;

      let assignmentStatus: string | undefined;
      if (assignedTo !== undefined) {
        assignmentStatus = assignedTo ? "pending_acceptance" : "unassigned";
      }

      const updated = await prisma.chore.update({
        where: { id },
        data: {
          ...(title !== undefined && { title }),
          ...(category !== undefined && { category }),
          ...(timeSlot !== undefined && { timeSlot }),
          ...(assignedTo !== undefined && { assignedTo }),
          ...(assignmentStatus !== undefined && { assignmentStatus }),
          ...(status !== undefined && { status }),
          ...(dueDate !== undefined && {
            dueDate: dueDate ? new Date(dueDate) : null,
          }),
          ...(priority !== undefined && { priority }),
          ...(description !== undefined && {
            description: description || null,
          }),
          ...(recurrence !== undefined && { recurrence: recurrence || null }),
        },
      });

      // Record history for status changes
      if (status !== undefined && status !== chore.status) {
        if (status === "done") {
          await recordHistory(id, chore.familyId, req.userId!, "completed");
        } else if (status === "pending" && chore.status === "done") {
          await recordHistory(id, chore.familyId, req.userId!, "reopened");
        }
      }
      if (
        assignedTo !== undefined &&
        assignedTo !== chore.assignedTo &&
        assignedTo
      ) {
        await recordHistory(id, chore.familyId, req.userId!, "assigned");
      }

      res.json(updated);
    } catch (error) {
      console.error("Update chore error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);

router.patch(
  "/:id/assignment",
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const id = String(req.params.id);
      const { assignmentStatus } = req.body;

      if (
        !assignmentStatus ||
        !["accepted", "declined"].includes(assignmentStatus)
      ) {
        res
          .status(400)
          .json({ error: 'assignmentStatus must be "accepted" or "declined"' });
        return;
      }

      const chore = await prisma.chore.findUnique({ where: { id } });
      if (!chore) {
        res.status(404).json({ error: "Chore not found" });
        return;
      }

      if (chore.assignedTo !== req.userId) {
        res.status(403).json({
          error: "Only the assigned user can respond to this assignment",
        });
        return;
      }

      if (chore.assignmentStatus !== "pending_acceptance") {
        res
          .status(400)
          .json({ error: "Assignment has already been responded to" });
        return;
      }

      const updated = await prisma.chore.update({
        where: { id },
        data: { assignmentStatus },
      });

      await recordHistory(id, chore.familyId, req.userId!, assignmentStatus);

      res.json(updated);
    } catch (error) {
      console.error("Update assignment error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);

// Complete a chore with optional note and photo
router.post(
  "/:id/complete",
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const id = String(req.params.id);
      const { note, photoUrl } = req.body;
      const chore = await prisma.chore.findUnique({ where: { id } });
      if (!chore) {
        res.status(404).json({ error: "Chore not found" });
        return;
      }
      if (!(await verifyFamilyMembership(req.userId!, chore.familyId))) {
        res.status(403).json({ error: "Forbidden" });
        return;
      }

      await prisma.chore.update({ where: { id }, data: { status: "done" } });

      // Record history with note
      await prisma.choreHistory.create({
        data: {
          choreId: id,
          familyId: chore.familyId,
          userId: req.userId!,
          action: note ? `completed: ${note}` : "completed",
        },
      });

      res.json({ success: true });
    } catch (error) {
      console.error("Complete chore error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);

// Get history for a specific chore
router.get(
  "/:id/history",
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const id = String(req.params.id);
      const chore = await prisma.chore.findUnique({ where: { id } });
      if (!chore) {
        res.status(404).json({ error: "Chore not found" });
        return;
      }
      if (!(await verifyFamilyMembership(req.userId!, chore.familyId))) {
        res.status(403).json({ error: "Forbidden" });
        return;
      }

      const history = await prisma.choreHistory.findMany({
        where: { choreId: id },
        orderBy: { createdAt: "asc" },
      });

      const userIds = Array.from(
        new Set(history.map((h: any) => h.userId)),
      ) as string[];
      const users = await prisma.user.findMany({
        where: { id: { in: userIds } },
        select: { id: true, displayName: true },
      });

      const result = history.map((h: any) => ({
        ...h,
        createdAt: h.createdAt.toISOString(),
        userName:
          users.find((u) => u.id === h.userId)?.displayName || "Unknown",
      }));

      res.json(result);
    } catch (error) {
      console.error("Chore history error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);

// Get comments for a chore
router.get(
  "/:id/comments",
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const id = String(req.params.id);
      const chore = await prisma.chore.findUnique({ where: { id } });
      if (!chore) {
        res.status(404).json({ error: "Chore not found" });
        return;
      }
      if (!(await verifyFamilyMembership(req.userId!, chore.familyId))) {
        res.status(403).json({ error: "Forbidden" });
        return;
      }

      const comments = await prisma.choreComment.findMany({
        where: { choreId: id },
        orderBy: { createdAt: "asc" },
      });

      const userIds = Array.from(
        new Set(comments.map((c: any) => c.userId)),
      ) as string[];
      const users = await prisma.user.findMany({
        where: { id: { in: userIds } },
        select: { id: true, displayName: true },
      });

      const result = comments.map((c: any) => ({
        ...c,
        createdAt: c.createdAt.toISOString(),
        userName:
          users.find((u) => u.id === c.userId)?.displayName || "Unknown",
      }));

      res.json(result);
    } catch (error) {
      console.error("Get comments error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);

// Post a comment on a chore
router.post(
  "/:id/comments",
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const id = String(req.params.id);
      const { text } = req.body;

      if (!text || !text.trim()) {
        res.status(400).json({ error: "text is required" });
        return;
      }

      const chore = await prisma.chore.findUnique({ where: { id } });
      if (!chore) {
        res.status(404).json({ error: "Chore not found" });
        return;
      }
      if (!(await verifyFamilyMembership(req.userId!, chore.familyId))) {
        res.status(403).json({ error: "Forbidden" });
        return;
      }

      const comment = await prisma.choreComment.create({
        data: {
          choreId: id,
          userId: req.userId!,
          text: text.trim(),
        },
      });

      const user = await prisma.user.findUnique({
        where: { id: req.userId! },
        select: { displayName: true },
      });

      res.status(201).json({
        ...comment,
        createdAt: comment.createdAt.toISOString(),
        userName: user?.displayName || "Unknown",
      });
    } catch (error) {
      console.error("Post comment error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);

// Get chore stats for a family
router.get(
  "/stats",
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const familyId = String(req.query.familyId || "");
      if (!familyId) {
        res.status(400).json({ error: "familyId required" });
        return;
      }
      if (!(await verifyFamilyMembership(req.userId!, familyId))) {
        res.status(403).json({ error: "Forbidden" });
        return;
      }

      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const [total, done, overdue] = await Promise.all([
        prisma.chore.count({ where: { familyId } }),
        prisma.chore.count({ where: { familyId, status: "done" } }),
        prisma.chore.count({
          where: { familyId, status: { not: "done" }, dueDate: { lt: today } },
        }),
      ]);
      res.json({ total, done, pending: total - done, overdue });
    } catch (error) {
      console.error("Stats error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);

// Get chore history for a family
router.get(
  "/history",
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const familyId = String(req.query.familyId || "");
      const limit = Math.min(parseInt(String(req.query.limit || "20")), 100);
      if (!familyId) {
        res.status(400).json({ error: "familyId required" });
        return;
      }
      if (!(await verifyFamilyMembership(req.userId!, familyId))) {
        res.status(403).json({ error: "Forbidden" });
        return;
      }

      const history = await prisma.choreHistory.findMany({
        where: { familyId },
        orderBy: { createdAt: "desc" },
        take: limit,
      });

      const choreIds = Array.from(
        new Set(history.map((h: any) => h.choreId)),
      ) as string[];
      const userIds = Array.from(
        new Set(history.map((h: any) => h.userId)),
      ) as string[];
      const [chores, users] = await Promise.all([
        prisma.chore.findMany({
          where: { id: { in: choreIds } },
          select: { id: true, title: true },
        }),
        prisma.user.findMany({
          where: { id: { in: userIds } },
          select: { id: true, displayName: true },
        }),
      ]);

      const result = history.map((h: any) => ({
        ...h,
        createdAt: h.createdAt.toISOString(),
        userName:
          users.find((u) => u.id === h.userId)?.displayName || "Unknown",
        choreTitle: chores.find((c) => c.id === h.choreId)?.title || "Unknown",
      }));
      res.json(result);
    } catch (error) {
      console.error("History error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);

// Analytics endpoint
router.get(
  "/analytics",
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const familyId = String(req.query.familyId || "");
      const userId = req.userId!;
      if (!familyId) {
        res.status(400).json({ error: "familyId required" });
        return;
      }
      if (!(await verifyFamilyMembership(userId, familyId))) {
        res.status(403).json({ error: "Forbidden" });
        return;
      }

      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const now = new Date();

      // Stats
      const [total, done, overdue] = await Promise.all([
        prisma.chore.count({ where: { familyId } }),
        prisma.chore.count({ where: { familyId, status: "done" } }),
        prisma.chore.count({
          where: { familyId, status: { not: "done" }, dueDate: { lt: today } },
        }),
      ]);

      // Category breakdown
      const chores = await prisma.chore.findMany({
        where: { familyId },
        select: { category: true },
      });
      const categoryBreakdown: Record<string, number> = {};
      chores.forEach((c) => {
        categoryBreakdown[c.category] =
          (categoryBreakdown[c.category] || 0) + 1;
      });

      // Weekly completions (last 7 days)
      const weekStart = new Date(now);
      weekStart.setDate(now.getDate() - now.getDay() + 1); // Monday
      weekStart.setHours(0, 0, 0, 0);
      const weeklyHistory = await prisma.choreHistory.findMany({
        where: { familyId, action: "completed", createdAt: { gte: weekStart } },
      });
      const dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      const weeklyCompletions = dayNames.map((name, i) => {
        const dayDate = new Date(weekStart);
        dayDate.setDate(weekStart.getDate() + i);
        const dayStr = dayDate.toISOString().substring(0, 10);
        const count = weeklyHistory.filter(
          (h: any) => h.createdAt.toISOString().substring(0, 10) === dayStr,
        ).length;
        return { dayName: name, completed: count };
      });

      // Member contributions (this month)
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
      const monthlyHistory = await prisma.choreHistory.findMany({
        where: {
          familyId,
          action: "completed",
          createdAt: { gte: monthStart },
        },
      });
      const memberMap: Record<string, number> = {};
      monthlyHistory.forEach((h: any) => {
        memberMap[h.userId] = (memberMap[h.userId] || 0) + 1;
      });
      const memberIds = Object.keys(memberMap);
      const memberUsers =
        memberIds.length > 0
          ? await prisma.user.findMany({
              where: { id: { in: memberIds } },
              select: { id: true, displayName: true },
            })
          : [];
      const memberContributions = memberIds
        .map((uid) => ({
          userId: uid,
          displayName:
            memberUsers.find((u) => u.id === uid)?.displayName || "Unknown",
          count: memberMap[uid],
        }))
        .sort((a, b) => b.count - a.count);

      // Completion trend (last 4 weeks)
      const completionTrend = [];
      for (let w = 3; w >= 0; w--) {
        const ws = new Date(now);
        ws.setDate(now.getDate() - now.getDay() + 1 - w * 7);
        ws.setHours(0, 0, 0, 0);
        const we = new Date(ws);
        we.setDate(ws.getDate() + 6);
        we.setHours(23, 59, 59, 999);
        const count = await prisma.choreHistory.count({
          where: {
            familyId,
            action: "completed",
            createdAt: { gte: ws, lte: we },
          },
        });
        const label =
          w === 0 ? "This Week" : w === 1 ? "Last Week" : `Wk -${w}`;
        completionTrend.push({ label, rate: count });
      }

      // Streak for current user
      const userHistory = await prisma.choreHistory.findMany({
        where: { userId, familyId, action: "completed" },
        orderBy: { createdAt: "desc" },
        select: { createdAt: true },
      });
      const uniqueDays = Array.from(
        new Set(
          userHistory.map((h: any) =>
            h.createdAt.toISOString().substring(0, 10),
          ),
        ),
      ) as string[];
      let streak = 0;
      let checkDate = new Date();
      for (const dayStr of uniqueDays) {
        const day = new Date(dayStr);
        const diffMs =
          new Date(
            checkDate.getFullYear(),
            checkDate.getMonth(),
            checkDate.getDate(),
          ).getTime() -
          new Date(day.getFullYear(), day.getMonth(), day.getDate()).getTime();
        const diffDays = Math.round(diffMs / 86400000);
        if (diffDays <= 1) {
          streak++;
          checkDate = day;
        } else {
          break;
        }
      }

      res.json({
        stats: { total, done, pending: total - done, overdue },
        categoryBreakdown,
        weeklyCompletions,
        memberContributions,
        completionTrend,
        currentStreak: streak,
      });
    } catch (error) {
      console.error("Analytics error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);

// Get a single chore by ID
router.get(
  "/:id",
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const id = String(req.params.id);
      const chore = await prisma.chore.findUnique({ where: { id } });

      if (!chore) {
        res.status(404).json({ error: "Chore not found" });
        return;
      }

      if (!(await verifyFamilyMembership(req.userId!, chore.familyId))) {
        res.status(403).json({ error: "Not a member of this family" });
        return;
      }

      res.json(chore);
    } catch (error) {
      console.error("Get chore error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);

router.delete(
  "/:id",
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const id = String(req.params.id);
      const chore = await prisma.chore.findUnique({ where: { id } });

      if (!chore) {
        res.status(404).json({ error: "Chore not found" });
        return;
      }

      if (!(await verifyFamilyMembership(req.userId!, chore.familyId))) {
        res.status(403).json({ error: "Not a member of this family" });
        return;
      }

      await prisma.chore.delete({ where: { id } });
      res.json({ success: true });
    } catch (error) {
      console.error("Delete chore error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);

export default router;
