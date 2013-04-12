#region *   License     *
/*
    SimpleHelpers - MemoryCache   

    Copyright © 2013 Khalid Salomão

    Permission is hereby granted, free of charge, to any person
    obtaining a copy of this software and associated documentation
    files (the "Software"), to deal in the Software without
    restriction, including without limitation the rights to use,
    copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following
    conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
    OTHER DEALINGS IN THE SOFTWARE. 

    License: http://www.opensource.org/licenses/mit-license.php
    Website: https://github.com/khalidsalomao/SimpleHelpers.Net
 */
#endregion

using System;
using System.Linq;

namespace $rootnamespace$.SimpleHelpers
{
    /// <summary>
    /// Simple object in memory cache, with a background timer to clear expired objects.
    /// </summary>
    public class MemoryCache : MemoryCache<object>
    {
        /// <summary>
        /// Gets the stored value associated with the specified key and cast it to desired type.
        /// Returns null if not found or if the type cast failed.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <returns>The key value or null if not found or if the type cast failed.</returns>
        public static T GetAs<T> (string key) where T : class
        {
            return Get (key) as T;
        }

        /// <summary>
        /// Removes and returns the value associated with the specified key.
        /// Returns null if not found or if the type cast failed.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <returns>The key value or null if not found or if the type cast failed.</returns>
        public static T RemoveAs<T> (string key) where T : class
        {
            return Remove (key) as T;
        }
    }

    /// <summary>
    /// Simple object in memory cache, with a background timer to clear expired objects.
    /// </summary>
    public class MemoryCache<T> where T : class
    {
        private static readonly System.Collections.Concurrent.ConcurrentDictionary <string, CachedItem> m_cacheMap = new System.Collections.Concurrent.ConcurrentDictionary<string, CachedItem> (StringComparer.Ordinal);

        private static TimeSpan m_timeout = TimeSpan.FromMinutes (5);
        
        private static TimeSpan m_maintenanceStep = TimeSpan.FromMinutes (5);

        /// <summary>
        /// Expiration TimeSpan of stored items
        /// </summary>
        public static TimeSpan Expiration
        {
            get { return m_timeout; }
            set { m_timeout = value; }
        }

        /// <summary>
        /// Interval duration between checks for expired cached items by the internal timer thread.
        /// </summary>
        public static TimeSpan MaintenanceStep
        {
            get { return m_maintenanceStep; }
            set
            {
                if (m_maintenanceStep != value)
                {
                    m_maintenanceStep = value;
                    StopMaintenance ();
                    StartMaintenance ();
                }
            }
        }

        #region *   Events and Event Handlers   *

        public delegate void SimpleMemoryCacheItemExpirationEventHandler (string key, T item);

        public static event SimpleMemoryCacheItemExpirationEventHandler OnExpiration;
        
        private static bool HasEventListeners ()
        {
            if (OnExpiration != null)
            {
            	return OnExpiration.GetInvocationList ().Length != 0;
            }
            return false;
        }

        #endregion

        class CachedItem
        {
            public DateTime Updated;
            public T Data;
        }

        /// <summary>
        /// Gets the current number of item stored in the cache.
        /// </summary>
        public static int Count
        {
            get { return m_cacheMap.Count; }
        }

        /// <summary>
        /// Gets the stored value associated with the specified key.
        /// Return the default value if not found.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <returns>Stored value for the key or default value if not found</returns>
        public static T Get (string key)
        {
            CachedItem item;
            if (m_cacheMap.TryGetValue (key, out item))
                return item.Data;
            return null;
        }

        /// <summary>
        /// Stores or updates the value associated with the key.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <param name="data">Stored value.</param>
        public static void Set (string key, T data)
        {
            if (key == null | key.Length == 0 | data == null)
                throw new System.ArgumentNullException ("key");
            // add or update item
            m_cacheMap[key] = new CachedItem
            {
                Updated = DateTime.UtcNow,
                Data = data
            };
            // check if the timer is active
            StartMaintenance ();
        }

        /// <summary>
        /// Removes and returns the value associated with the specified key.
        /// Return the default value if not found.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <returns>Stored value for the key or default value if not found</returns>
        public static T Remove (string key)
        {
            CachedItem item;
            if (m_cacheMap.TryRemove (key, out item))                
                return item.Data;
            return default (T);
        }

        /// <summary>
        /// Remove all cached items.
        /// </summary>
        public static void Clear ()
        {
            m_cacheMap.Clear ();
        }

        /// <summary>
        /// Gets the stored value associated with the specified key or store a new value
        /// generated by the provided factory function and return it.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <param name="valueFactory">The value factory function.</param>
        /// <returns>Stored value for the key or default value if not found</returns>
        public static T GetOrAdd (string key, Func<string, T> valueFactory)
        { 
            CachedItem item;
            if (!m_cacheMap.TryGetValue (key, out item))
            {
                if (valueFactory == null)
                    throw new System.ArgumentNullException ("valueFactory");                    
                // create the new value
                T data = valueFactory (key);
                // add or update cache
                Set (key, data);
                return data;
            }
            else
            {
                return item.Data;
            }
        }

        /// <summary>
        /// Gets the stored value associated with the specified key or store a new value
        /// generated by the provided factory function and return it.
        /// If the value factory function is called to create a new item, a lock is aquired to supress
        /// multiple call to the factory function for the specified key (calls to others keys are not blocked). 
        /// If the lock times out (i.e. the factory takes more waitTimeout to create then new instance), the default value for the type is returned.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <param name="valueFactory">The value factory function.</param>
        /// <param name="waitTimeout">The wait timeout to sync.</param>
        /// <returns>Stored value for the key or default value if not found</returns>
        public static T GetOrSyncAdd (string key, Func<string, T> valueFactory, TimeSpan waitTimeout)
        {
            return GetOrSyncAdd (key, valueFactory, (int)waitTimeout.TotalMilliseconds);
        }

        /// <summary>
        /// Gets the stored value associated with the specified key or store a new value
        /// generated by the provided factory function and return it.
        /// If the value factory function is called to create a new item, a lock is aquired to supress
        /// multiple call to the factory function for the specified key (calls to others keys are not blocked).
        /// If the lock times out (i.e. the factory takes more waitTimeout to create then new instance), the default value for the type is returned.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <param name="valueFactory">The value factory function.</param>
        /// <param name="waitTimeoutMilliseconds">The wait timeout milliseconds.</param>
        /// <returns>Stored value for the key or default value if not found</returns>
        public static T GetOrSyncAdd (string key, Func<string, T> valueFactory, int waitTimeoutMilliseconds)
        {
            CachedItem item;
            if (!m_cacheMap.TryGetValue (key, out item))
            {
                // create a lock for this key
                using (var padlock = new NamedLock (key))
                {
                    if (padlock.Enter (waitTimeoutMilliseconds))
                    {
                        return GetOrAdd (key, valueFactory);                            
                    }
                    else
                    {
                        return default (T);
                    }
                }
            }
            return item.Data;
        }

        #region *   Cache Maintenance Task  *

        private static System.Threading.Timer m_maintenanceTask = null;
        private static readonly object m_lock = new object ();
        private static int m_executing = 0;

        private static void StartMaintenance ()
        {
            if (m_maintenanceTask == null)
            {
                lock (m_lock)
                {
                    if (m_maintenanceTask == null)
                    {
                        m_maintenanceTask = new System.Threading.Timer (ExecuteMaintenance, null, m_maintenanceStep, m_maintenanceStep);
                    }
                }
            }
        }

        private static void StopMaintenance ()
        {
            lock (m_lock)
            {
                if (m_maintenanceTask != null)
                    m_maintenanceTask.Dispose ();
                m_maintenanceTask = null;
            }
        }

        private static void ExecuteMaintenance (object state)
        {
            // check if a step is already executing
            if (System.Threading.Interlocked.CompareExchange (ref m_executing, 1, 0) != 0)
                return;
            // try to fire OnExpiration event
            try
            {
                // stop timed task if queue is empty
                if (m_cacheMap.Count == 0)
                {
                    StopMaintenance ();
                    // check again if the queue is empty
                    if (m_cacheMap.Count != 0)
                        StartMaintenance ();
                }
                else
                {
                    CachedItem item;
                    DateTime oldThreshold = DateTime.UtcNow - m_timeout;
                    bool hasEvents = HasEventListeners ();
                    // select elegible records
                    var expiredItems = m_cacheMap.Where (i => i.Value.Updated < oldThreshold).Select (i => i.Key);
                    // remove from cache and fire OnExpiration event
                    foreach (var key in expiredItems)
                    {
                        m_cacheMap.TryRemove (key, out item);
                        if (hasEvents)
                        {
                            OnExpiration (key, item.Data);
                        }
                    }
                }
            }
            finally
            {
                // release lock
                System.Threading.Interlocked.Exchange (ref m_executing, 0);
            }
        }
        
        #endregion
    }
}