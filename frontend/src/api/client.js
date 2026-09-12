import axios from "axios";
import { useAuth } from "@clerk/clerk-react";
import { useMemo } from "react";

const BASE_URL = import.meta.env.VITE_API_BASE_URL;

export const useApiClient = () => {
  const { getToken } = useAuth();

  const client = useMemo(() => {
    const instance = axios.create({ baseURL: BASE_URL });
    instance.interceptors.request.use(async (config) => {
      const token = await getToken();
      if (token) config.headers.Authorization = "Bearer " + token;
      return config;
    });
    return instance;
  }, [getToken]);

  return client;
};
