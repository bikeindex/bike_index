const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

interface ApiError {
  detail: string;
}

class ApiClient {
  private baseUrl: string;
  private token: string | null = null;

  constructor(baseUrl: string = API_BASE_URL) {
    this.baseUrl = baseUrl;
    // Load token from localStorage if available
    if (typeof window !== 'undefined') {
      this.token = localStorage.getItem('auth_token');
    }
  }

  setToken(token: string) {
    this.token = token;
    if (typeof window !== 'undefined') {
      localStorage.setItem('auth_token', token);
    }
  }

  clearToken() {
    this.token = null;
    if (typeof window !== 'undefined') {
      localStorage.removeItem('auth_token');
    }
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
      ...options.headers,
    };

    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }

    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      ...options,
      headers,
    });

    if (!response.ok) {
      const error: ApiError = await response.json().catch(() => ({
        detail: 'An error occurred',
      }));
      throw new Error(error.detail);
    }

    // Handle 204 No Content
    if (response.status === 204) {
      return {} as T;
    }

    return response.json();
  }

  // Auth endpoints
  async register(data: {
    email: string;
    password: string;
    name?: string;
    username?: string;
  }) {
    return this.request('/api/v1/auth/register', {
      method: 'POST',
      body: JSON.stringify({ ...data, terms_of_service: true }),
    });
  }

  async login(email: string, password: string) {
    const formData = new URLSearchParams();
    formData.append('username', email); // OAuth2PasswordRequestForm uses 'username'
    formData.append('password', password);

    const response = await fetch(`${this.baseUrl}/api/v1/auth/login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: formData,
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({
        detail: 'Login failed',
      }));
      throw new Error(error.detail);
    }

    const data = await response.json();
    this.setToken(data.access_token);
    return data;
  }

  async getCurrentUser() {
    return this.request('/api/v1/users/me', { method: 'GET' });
  }

  // Bike endpoints
  async createBike(data: {
    serial_number: string;
    manufacturer_id?: number;
    frame_model?: string;
    year?: number;
    description?: string;
    primary_frame_color_id?: number;
  }) {
    return this.request('/api/v1/bikes/', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async getBikes(params?: { stolen?: boolean; skip?: number; limit?: number }) {
    const queryParams = new URLSearchParams();
    if (params?.stolen !== undefined)
      queryParams.append('stolen', String(params.stolen));
    if (params?.skip) queryParams.append('skip', String(params.skip));
    if (params?.limit) queryParams.append('limit', String(params.limit));

    const query = queryParams.toString();
    return this.request(`/api/v1/bikes/${query ? `?${query}` : ''}`, {
      method: 'GET',
    });
  }

  async getBike(id: number) {
    return this.request(`/api/v1/bikes/${id}`, { method: 'GET' });
  }

  // Marketplace endpoints
  async createListing(data: {
    title: string;
    description?: string;
    price: number;
    condition: string;
    bike_id?: number;
  }) {
    return this.request('/api/v1/marketplace/', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async getListings(params?: {
    active_only?: boolean;
    skip?: number;
    limit?: number;
  }) {
    const queryParams = new URLSearchParams();
    if (params?.active_only !== undefined)
      queryParams.append('active_only', String(params.active_only));
    if (params?.skip) queryParams.append('skip', String(params.skip));
    if (params?.limit) queryParams.append('limit', String(params.limit));

    const query = queryParams.toString();
    return this.request(`/api/v1/marketplace/${query ? `?${query}` : ''}`, {
      method: 'GET',
    });
  }

  async getListing(id: number) {
    return this.request(`/api/v1/marketplace/${id}`, { method: 'GET' });
  }
}

export const api = new ApiClient();
