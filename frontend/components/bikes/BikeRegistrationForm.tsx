'use client';

import { useState } from 'react';
import { api } from '@/lib/api';

export default function BikeRegistrationForm() {
  const [formData, setFormData] = useState({
    serial_number: '',
    frame_model: '',
    year: '',
    description: '',
  });
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSuccess(false);
    setLoading(true);

    try {
      await api.createBike({
        serial_number: formData.serial_number,
        frame_model: formData.frame_model || undefined,
        year: formData.year ? parseInt(formData.year) : undefined,
        description: formData.description || undefined,
      });
      setSuccess(true);
      setFormData({ serial_number: '', frame_model: '', year: '', description: '' });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Registration failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="max-w-2xl mx-auto p-6 bg-white rounded-lg shadow-md">
      <h2 className="text-2xl font-bold mb-6">Register Your Bike</h2>

      {success && (
        <div className="mb-4 p-3 bg-green-100 border border-green-400 text-green-700 rounded">
          Bike registered successfully!
        </div>
      )}

      {error && (
        <div className="mb-4 p-3 bg-red-100 border border-red-400 text-red-700 rounded">
          {error}
        </div>
      )}

      <div className="mb-4">
        <label htmlFor="serial_number" className="block text-sm font-medium mb-2">
          Serial Number *
        </label>
        <input
          type="text"
          id="serial_number"
          value={formData.serial_number}
          onChange={(e) => setFormData({ ...formData, serial_number: e.target.value })}
          className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          required
        />
      </div>

      <div className="mb-4">
        <label htmlFor="frame_model" className="block text-sm font-medium mb-2">
          Frame Model
        </label>
        <input
          type="text"
          id="frame_model"
          value={formData.frame_model}
          onChange={(e) => setFormData({ ...formData, frame_model: e.target.value })}
          className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <div className="mb-4">
        <label htmlFor="year" className="block text-sm font-medium mb-2">
          Year
        </label>
        <input
          type="number"
          id="year"
          value={formData.year}
          onChange={(e) => setFormData({ ...formData, year: e.target.value })}
          className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          min="1900"
          max={new Date().getFullYear() + 1}
        />
      </div>

      <div className="mb-6">
        <label htmlFor="description" className="block text-sm font-medium mb-2">
          Description
        </label>
        <textarea
          id="description"
          value={formData.description}
          onChange={(e) => setFormData({ ...formData, description: e.target.value })}
          className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          rows={4}
        />
      </div>

      <button
        type="submit"
        disabled={loading}
        className="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed"
      >
        {loading ? 'Registering...' : 'Register Bike'}
      </button>
    </form>
  );
}
