import { getAuth } from "@clerk/express";

export const getUserId = (req) => {
  const { userId } = getAuth(req);
  return userId;
};
